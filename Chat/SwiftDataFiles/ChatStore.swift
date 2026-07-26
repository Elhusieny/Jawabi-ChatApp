// MARK: - ChatStore.swift
// The single source of truth for persisted chats & messages.
// Inject it via .environment(chatStore) in your App entry-point
// (see AppSetup.swift for the wiring example).

import Foundation
import SwiftData
import Combine

@MainActor
final class ChatStore: ObservableObject {

    // ── Published state consumed by views ─────────────────────────────────
    @Published private(set) var chats: [ChatEntity] = []

    // ── Internal ──────────────────────────────────────────────────────────
    private let modelContext: ModelContext
    private var cancellables = Set<AnyCancellable>()

    /// The userId that belongs to the currently logged-in user.
    /// Set this after login before using the store.
    var localUserId: String = UserDefaults.standard.string(forKey: "userId") ?? ""

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Init
    // ─────────────────────────────────────────────────────────────────────

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        fetchChats()
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: SignalR Binding
    // Observe the SignalRService and persist whatever arrives.
    // Call this once after your SignalRService is ready.
    // ─────────────────────────────────────────────────────────────────────

    func bind(to signalR: SignalRService) {

        // ── Incoming message (private or group) ───────────────────────────
        signalR.$receivedMessage
            .compactMap { $0 }
            .sink { [weak self] msg in
                self?.handleIncomingMessage(msg)
            }
            .store(in: &cancellables)

        // ── Message history (bulk load on JoinRoom) ────────────────────────
        signalR.$receivedMessageHistory
            .filter { !$0.isEmpty }
            .sink { [weak self] history in
                // history items all share the same chatId (if present)
                guard let chatId = history.first?.chatId ?? history.first?.chatId else { return }
                self?.handleMessageHistory(history, chatId: chatId)
            }
            .store(in: &cancellables)

        // ── Private message history with seen status ───────────────────────
        signalR.$privateMessageHistory
            .filter { !$0.isEmpty }
            .sink { [weak self] history in
                self?.handlePrivateMessageHistory(history)
            }
            .store(in: &cancellables)

        // ── Message deleted ────────────────────────────────────────────────
        signalR.$deletedMessageId
            .compactMap { $0 }
            .sink { [weak self] messageId in
                self?.markMessageDeleted(messageId: messageId)
            }
            .store(in: &cancellables)

        // ── Seen status ────────────────────────────────────────────────────
        signalR.$seenStatus
            .compactMap { $0 }
            .sink { [weak self] seen in
                self?.markChatSeen(chatId: seen.chatId)
            }
            .store(in: &cancellables)

        // ── User online/offline ────────────────────────────────────────────
        signalR.$userStatus
            .compactMap { $0 }
            .sink { [weak self] status in
                self?.updateUserStatus(userId: status.userName,
                                       isOnline: status.isOnline,
                                       lastSeen: status.lastSeen)
            }
            .store(in: &cancellables)

        // ── File scan result ───────────────────────────────────────────────
        signalR.$fileStatusUpdated
            .compactMap { $0 }
            .sink { [weak self] fileData in
                self?.applyFileStatus(fileData)
            }
            .store(in: &cancellables)
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Public API — Chat management
    // ─────────────────────────────────────────────────────────────────────

    /// Call this when the server returns the full chat list (e.g. from a REST API).
    func upsertChat(chatId: Int,
                    title: String,
                    isGroup: Bool = false,
                    avatarUrl: String? = nil) {
        let chat = fetchOrCreateChat(chatId: chatId, title: title, isGroup: isGroup, avatarUrl: avatarUrl)
        _ = chat   // side-effect: inserts if new
        saveContext()
        fetchChats()
    }

    /// Returns messages for one chat, sorted oldest-first.
    func messages(for chatId: Int) -> [MessageEntity] {
        guard let chat = fetchChat(chatId: chatId) else { return [] }
        return chat.messages
            .filter { !$0.isDeleted }
            .sorted { $0.timestamp < $1.timestamp }
    }

    /// Call after the user sends a message so it appears immediately (optimistic insert).
    @discardableResult
    func insertOutgoingMessage(chatId: Int,
                               text: String,
                               type: MessageType = .text,
                               fileUrl: String? = nil,
                               fileName: String? = nil,
                               fileSize: Int64 = 0,
                               fileExtension: String? = nil) -> MessageEntity? {
        guard let chat = fetchChat(chatId: chatId) else { return nil }

        let msg = MessageEntity(
            chat: chat,
            fromUserId: localUserId,
            fromDisplayName: UserDefaults.standard.string(forKey: "displayName") ?? "Me",
            text: text,
            isOutgoing: true,
            rawMessageType: type.rawValue,
            fileUrl: fileUrl,
            fileName: fileName,
            fileSize: fileSize,
            fileExtension: fileExtension
        )
        modelContext.insert(msg)
        updateChatPreview(chat: chat, text: text, date: msg.timestamp)
        saveContext()
        fetchChats()
        return msg
    }

    /// Reset unread counter when the user opens a chat.
    func clearUnread(chatId: Int) {
        guard let chat = fetchChat(chatId: chatId) else { return }
        chat.unreadCount = 0
        saveContext()
        fetchChats()
    }

    /// Wipe all persisted data (useful on logout).
    func clearAll() {
        try? modelContext.delete(model: MessageEntity.self)
        try? modelContext.delete(model: ChatEntity.self)
        try? modelContext.delete(model: UserEntity.self)
        saveContext()
        chats = []
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Private — SignalR event handlers
    // ─────────────────────────────────────────────────────────────────────

    private func handleIncomingMessage(_ msg: ReceivedPrivateMessage) {
        guard let chatId = msg.chatId ?? msg.ChatId else {
            print("⚠️ ChatStore: incoming message has no chatId — skipping")
            return
        }

        let chat = fetchOrCreateChat(chatId: chatId,
                                     title: msg.from ?? "Chat \(chatId)")

        // Deduplicate by messageId when server provides one
        if let msgId = msg.messageId ?? msg.MessageId, msgId > 0 {
            let existing = chat.messages.first { $0.messageId == msgId }
            if existing != nil { return }
        }

        let isOutgoing = (msg.from ?? "") == localUserId ||
                         (msg.from ?? "") == UserDefaults.standard.string(forKey: "displayName")

        let entity = MessageEntity(
            messageId: msg.messageId ?? msg.MessageId ?? 0,
            chat: chat,
            fromUserId: msg.from ?? "",
            fromDisplayName: msg.from ?? "",
            text: msg.text ?? msg.Text ?? "",
            timestamp: msg.timeStamp ?? msg.TimeStamp ?? .now,
            isOutgoing: isOutgoing,
            rawMessageType: (msg.type ?? .text).rawValue,
            fileUrl: msg.fileUrl,
            fileName: msg.fileName,
            fileSize: msg.fileSize ?? 0,
            fileExtension: msg.extension,
            isSafe: msg.isSafe ?? true
        )
        modelContext.insert(entity)

        if !isOutgoing {
            chat.unreadCount += 1
        }

        let preview = entity.text.isEmpty ? (entity.fileName ?? "📎 File") : entity.text
        updateChatPreview(chat: chat, text: preview, date: entity.timestamp)
        saveContext()
        fetchChats()
    }

    private func handleMessageHistory(_ history: [ReceivedPrivateMessage], chatId: Int) {
        let chat = fetchOrCreateChat(chatId: chatId, title: "Chat \(chatId)")
        let existingIds = Set(chat.messages.map { $0.messageId })

        for msg in history {
            let id = msg.messageId ?? msg.MessageId ?? 0
            guard !existingIds.contains(id) || id == 0 else { continue }

            let isOutgoing = (msg.from ?? "") == localUserId

            let entity = MessageEntity(
                messageId: id,
                chat: chat,
                fromUserId: msg.from ?? "",
                fromDisplayName: msg.from ?? "",
                text: msg.text ?? msg.Text ?? "",
                timestamp: msg.timeStamp ?? msg.TimeStamp ?? .now,
                isOutgoing: isOutgoing,
                rawMessageType: (msg.type ?? .text).rawValue,
                fileUrl: msg.fileUrl,
                fileName: msg.fileName,
                fileSize: msg.fileSize ?? 0,
                fileExtension: msg.extension,
                isSafe: msg.isSafe ?? true
            )
            modelContext.insert(entity)
        }

        if let last = history.last {
            let preview = last.text ?? last.Text ?? ""
            let date    = last.timeStamp ?? last.TimeStamp ?? .now
            updateChatPreview(chat: chat, text: preview, date: date)
        }

        saveContext()
        fetchChats()
    }

    private func handlePrivateMessageHistory(_ history: [MessageWithSeenStatus]) {
        guard let firstChatId = history.first.flatMap({ _ in
            // MessageWithSeenStatus has no chatId — caller must know which chat
            // this was fetched for.  We cannot derive it here, so we skip the
            // bulk-upsert path and rely on handleMessageHistory instead.
            return Optional<Int>.none
        }) else { return }
        _ = firstChatId
    }

    /// Convenience: upsert private message history when the caller knows chatId.
    func handlePrivateMessageHistory(_ history: [MessageWithSeenStatus], chatId: Int) {
        let chat = fetchOrCreateChat(chatId: chatId, title: "Chat \(chatId)")
        let existingIds = Set(chat.messages.map { $0.messageId })

        for msg in history {
            guard !existingIds.contains(msg.id) else {
                // Update seen status on existing record
                if let entity = chat.messages.first(where: { $0.messageId == msg.id }) {
                    entity.isSeen = msg.isSeen ?? false
                }
                continue
            }

            let isOutgoing = (msg.from ?? "") == localUserId

            let entity = MessageEntity(
                messageId: msg.id,
                chat: chat,
                fromUserId: msg.from ?? "",
                fromDisplayName: msg.from ?? "",
                text: msg.displayText,
                timestamp: msg.timeStamp ?? .now,
                isOutgoing: isOutgoing,
                rawMessageType: (msg.type ?? .text).rawValue,
                fileUrl: msg.fileUrl,
                fileName: msg.fileName,
                fileSize: msg.fileSize ?? 0,
                fileExtension: msg.extension,
                isSeen: msg.isSeen ?? false,
                isSafe: msg.isSafe ?? true
            )
            modelContext.insert(entity)
        }

        if let last = history.last {
            updateChatPreview(chat: chat, text: last.displayText, date: last.timeStamp ?? .now)
        }

        saveContext()
        fetchChats()
    }

    private func markMessageDeleted(messageId: Int) {
        let predicate = #Predicate<MessageEntity> { $0.messageId == messageId }
        let results   = (try? modelContext.fetch(FetchDescriptor(predicate: predicate))) ?? []
        results.forEach { $0.isDeleted = true }
        saveContext()
        fetchChats()
    }

    private func markChatSeen(chatId: Int) {
        guard let chat = fetchChat(chatId: chatId) else { return }
        chat.messages
            .filter { $0.isOutgoing && !$0.isSeen }
            .forEach { $0.isSeen = true }
        saveContext()
    }

    private func updateUserStatus(userId: String, isOnline: Bool, lastSeen: Date?) {
        let predicate = #Predicate<UserEntity> { $0.userId == userId }
        let results   = (try? modelContext.fetch(FetchDescriptor(predicate: predicate))) ?? []
        if let user = results.first {
            user.isOnline = isOnline
            user.lastSeen = lastSeen
            saveContext()
        }
    }

    private func applyFileStatus(_ data: FileStatusUpdatedData) {
        let messageId = data.messageId
        let predicate = #Predicate<MessageEntity> { $0.messageId == messageId }
        let results   = (try? modelContext.fetch(FetchDescriptor(predicate: predicate))) ?? []
        if let entity = results.first {
            entity.isSafe   = data.isSafe
            entity.fileUrl  = data.fileUrl
            if let name = data.fileName { entity.fileName = name }
            saveContext()
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Private — Helpers
    // ─────────────────────────────────────────────────────────────────────

    @discardableResult
    private func fetchOrCreateChat(chatId: Int,
                                   title: String,
                                   isGroup: Bool = false,
                                   avatarUrl: String? = nil) -> ChatEntity {
        if let existing = fetchChat(chatId: chatId) { return existing }
        let chat = ChatEntity(chatId: chatId,
                              title: title,
                              isGroup: isGroup,
                              avatarUrl: avatarUrl)
        modelContext.insert(chat)
        return chat
    }

    private func fetchChat(chatId: Int) -> ChatEntity? {
        let predicate = #Predicate<ChatEntity> { $0.chatId == chatId }
        return try? modelContext.fetch(FetchDescriptor(predicate: predicate)).first
    }

    private func updateChatPreview(chat: ChatEntity, text: String, date: Date) {
        chat.lastMessagePreview = text
        chat.lastMessageDate    = date
        chat.updatedAt          = date
    }

    private func fetchChats() {
        let sort = SortDescriptor(\ChatEntity.updatedAt, order: .reverse)
        chats = (try? modelContext.fetch(FetchDescriptor(sortBy: [sort]))) ?? []
    }

    private func saveContext() {
        try? modelContext.save()
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: User management
    // ─────────────────────────────────────────────────────────────────────

    /// Upsert a contact.  Call this when you receive a user list from the server.
    func upsertUser(userId: String,
                    displayName: String,
                    avatarUrl: String? = nil,
                    isOnline: Bool = false) {
        let predicate = #Predicate<UserEntity> { $0.userId == userId }
        if let existing = try? modelContext.fetch(FetchDescriptor(predicate: predicate)).first {
            existing.displayName = displayName
            if let url = avatarUrl { existing.avatarUrl = url }
            existing.isOnline = isOnline
        } else {
            modelContext.insert(UserEntity(userId: userId,
                                           displayName: displayName,
                                           avatarUrl: avatarUrl,
                                           isOnline: isOnline))
        }
        saveContext()
    }
}