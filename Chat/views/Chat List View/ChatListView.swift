import SwiftUI

// MARK: - ChatListView (WhatsApp-style, refactored)
//
// Changes from the original:
// 1. The duplicate hand-built search bar is gone — `.searchable` (already
//    applied) is the only search UI now, so there's one source of truth
//    for `searchText` instead of two competing fields.
// 2. The custom "hide the nav bar, draw my own" header is replaced with a
//    native `.toolbar`: a `.principal` item for the branded title and a
//    `.navigationBarTrailing` `Menu` for actions. Same look, standard
//    system behavior (Dynamic Type, VoiceOver, swipe-back, etc.) for free.
// 3. Row navigation now uses `NavigationLink(value:)` +
//    `navigationDestination(for: Int.self)`, replacing the deprecated
//    `NavigationLink(destination:tag:selection:)` + hidden-ZStack hack.
//    Both row taps and push-notification-driven navigation now go through
//    the exact same destination resolver.
// 4. Startup sequencing, entity→model mapping, pending-notification
//    retry logic, network monitoring, and logout bookkeeping have all
//    moved into small single-purpose services (see the accompanying
//    files) instead of living inline in `onAppear`.
struct ChatListView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var chatViewModel: ChatViewModel
    @EnvironmentObject var chatStore: ChatStore
    @EnvironmentObject var profilePictureVM: ProfilePictureViewModel
    @StateObject private var navigationManager = NavigationManager.shared

    @State private var showingNewChat = false
    @State private var showingCreateRoom = false
    @State private var showingProfile = false
    @State private var showingSettings = false
    @State private var showingLogoutConfirmation = false
    @State private var searchText = ""

    @State private var isOffline = false
    @State private var pendingChatIdFromNotification: Int?

    // MARK: - Services (single responsibility each)
    // `NetworkMonitorService`/`NetworkMonitoring` reused from the
    // ChatDetailView refactor — same protocol, same implementation.
    @State private var networkMonitor: NetworkMonitoring = NetworkMonitorService()
    private let entityMapper: ChatEntityMapping
    private let bootstrapService: ChatListBootstrapping
    private let pendingNavigationCoordinator: PendingChatNavigating
    private let logoutCoordinator: AuthSessionLogoutHandling

    private let primaryColor: Color = .jawabiPrimary

    init(
        entityMapper: ChatEntityMapping = ChatEntityToChatMapper(),
        bootstrapService: ChatListBootstrapping = ChatListBootstrapService(),
        pendingNavigationCoordinator: PendingChatNavigating = PendingChatNavigationCoordinator(),
        logoutCoordinator: AuthSessionLogoutHandling = LogoutCoordinator()
    ) {
        self.entityMapper = entityMapper
        self.bootstrapService = bootstrapService
        self.pendingNavigationCoordinator = pendingNavigationCoordinator
        self.logoutCoordinator = logoutCoordinator
    }

    // Reads from ChatStore (SwiftData) — the single source of truth.
    var filteredChats: [ChatEntity] {
        guard !searchText.isEmpty else { return chatStore.chats }
        return chatStore.chats.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            ($0.lastMessagePreview ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack(path: $navigationManager.navigationPath) {
            ZStack(alignment: .bottomTrailing) {
                Color(.systemBackground).ignoresSafeArea()

                if chatStore.chats.isEmpty {
                    emptyStateView
                } else {
                    chatListContent
                }

                fabButton
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .searchable(text: $searchText, prompt: "Search chats...")
            .navigationDestination(for: Int.self, destination: chatDestination)
            .sheet(isPresented: $showingNewChat) {
                NewChatView(chatViewModel: chatViewModel, isPresented: $showingNewChat)
            }
            .sheet(isPresented: $showingCreateRoom) {
                CreateRoomView {
                    chatViewModel.refreshChats()
                    chatViewModel.fetchAllChatsFromServer()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        chatViewModel.autoJoinAllChats()
                    }
                }
            }
            .sheet(isPresented: $showingProfile) {
                ProfileView(authViewModel: authViewModel, isPresented: $showingProfile)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView().environmentObject(authViewModel)
            }
            .onAppear { handleOnAppear() }
            .onDisappear { networkMonitor.stopMonitoring() }
            .onReceive(chatStore.$chats) { entities in
                chatViewModel.syncChatsFromStore(entities)
            }
            .environmentObject(navigationManager)
            .onReceive(NotificationCenter.default.publisher(for: .navigateToChatDetail), perform: handleNavigateToChatDetailNotification)
            .onReceive(NotificationCenter.default.publisher(for: .networkStatusChanged), perform: handleNetworkStatusChangedNotification)
            .onReceive(NotificationCenter.default.publisher(for: .chatListShouldRefresh)) { _ in
                chatStore.refreshChatsFromServer()
            }
            .onReceive(NotificationCenter.default.publisher(for: .chatMembersUpdated)) { _ in
                chatStore.refreshChatsFromServer()
            }
            .confirmationDialog("Log Out", isPresented: $showingLogoutConfirmation) {
                Button("Log Out", role: .destructive) {
                    logoutCoordinator.logout(currentUsername: authViewModel.currentUser, authViewModel: authViewModel)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to log out?\nYour account will be saved for quick login.")
            }
            .alert("Error", isPresented: .constant(chatViewModel.errorMessage != nil)) {
                Button("OK", role: .cancel) { chatViewModel.errorMessage = nil }
            } message: {
                Text(chatViewModel.errorMessage ?? "Unknown error")
            }
        }
        .accentColor(primaryColor)
    }

    // MARK: - Toolbar (native, replaces the custom header)

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text("Jawabi")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(primaryColor)
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button {
                    showingProfile = true
                } label: {
                    Label("My Profile", systemImage: "person.circle")
                }

                Button {
                    showingCreateRoom = true
                } label: {
                    Label("New Group", systemImage: "person.2")
                }

                Divider()

                Button(role: .destructive) {
                    showingLogoutConfirmation = true
                } label: {
                    Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.title2)
                    .foregroundColor(primaryColor)
            }
        }
    }

    // MARK: - Navigation destination
    // Shared by row taps (`NavigationLink(value:)`) and by
    // notification-driven navigation (`navigationManager.navigationPath`).

    @ViewBuilder
    private func chatDestination(for chatId: Int) -> some View {
        if let chat = chatViewModel.chats.first(where: { $0.id == chatId }) {
            ChatDetailView(chat: chat, chatViewModel: chatViewModel)
                .onAppear { pendingChatIdFromNotification = nil }
        } else if let entity = chatStore.chats.first(where: { $0.chatId == chatId }) {
            ChatDetailView(chat: entityMapper.map(entity, using: chatStore), chatViewModel: chatViewModel)
                .onAppear { pendingChatIdFromNotification = nil }
        } else {
            VStack(spacing: 16) {
                ProgressView().tint(primaryColor)
                Text("Loading chat...").foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground).ignoresSafeArea())
            .onAppear {
                chatViewModel.loadChat(chatId: chatId)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    chatViewModel.fetchAllChatsFromServer()
                }
            }
        }
    }

    // MARK: - Lifecycle handlers (thin — delegate to services)

    private func handleOnAppear() {
        bootstrapService.bootstrap(chatStore: chatStore, chatViewModel: chatViewModel, isOffline: isOffline)

        networkMonitor.startMonitoring { offline in
            isOffline = offline
            if !offline {
                chatStore.refreshChatsFromServer()
                chatViewModel.connectSignalR()
            }
        }

        if let pendingChatId = pendingChatIdFromNotification {
            pendingNavigationCoordinator.resolvePendingNavigation(chatId: pendingChatId, chatStore: chatStore) { chatId in
                navigationManager.navigationPath.append(chatId)
                pendingChatIdFromNotification = nil
            }
        }
    }

    private func handleNavigateToChatDetailNotification(_ notification: Notification) {
        guard let chatId = notification.userInfo?["chatId"] as? Int else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            navigationManager.navigateToChat(chatId: chatId)
            if navigationManager.navigationPath.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    navigationManager.navigationPath.append(chatId)
                }
            }
        }
    }

    private func handleNetworkStatusChangedNotification(_ notification: Notification) {
        guard let isConnected = notification.userInfo?["isConnected"] as? Bool else { return }
        isOffline = !isConnected
        if isConnected {
            chatStore.refreshChatsFromServer()
            chatViewModel.connectSignalR()
        }
    }

    // MARK: - FAB (WhatsApp-style Plus with Chat)

    private var fabButton: some View {
        Button {
            guard UserDefaults.standard.string(forKey: "authToken") != nil else { return }
            showingNewChat = true
            chatViewModel.loadAllUsers(forceRefresh: false)
        } label: {
            ZStack {
                Circle()
                    .fill(primaryColor)
                    .frame(width: 58, height: 58)
                    .shadow(color: primaryColor.opacity(0.4), radius: 12, x: 0, y: 6)

                ZStack {
                    Image(systemName: "message.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)

                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .background(
                            Circle()
                                .fill(primaryColor)
                                .frame(width: 16, height: 16)
                        )
                        .offset(x: 14, y: 14)
                }
            }
        }
        .padding(.trailing, 20)
        .padding(.bottom, 28)
    }

    // MARK: - Chat List

    private var chatListContent: some View {
        List {
            ForEach(filteredChats, id: \.chatId) { chat in
                NavigationLink(value: chat.chatId) {
                    ChatRow(chat: chat, chatViewModel: chatViewModel)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                .listRowSeparatorTint(Color(.systemGray5))
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(primaryColor.opacity(0.12))
                    .frame(width: 120, height: 120)

                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 48))
                    .foregroundColor(primaryColor)
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(spacing: 8) {
                Text("No Chats Yet")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.primary)

                Text("Tap the button below to start your first conversation")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 48)
            }

            Spacer()
        }
    }
}

// MARK: - Notification.Name constants
// Named, typed constants instead of NSNotification.Name("...") string
// literals scattered through the view — typo-proof and greppable.
extension Notification.Name {
    static let navigateToChatDetail = Notification.Name("NavigateToChatDetail")
    static let networkStatusChanged = Notification.Name("NetworkStatusChanged")
    static let chatListShouldRefresh = Notification.Name("ChatListShouldRefresh")
    static let chatMembersUpdated = Notification.Name("ChatMembersUpdated")
}

extension Chat {
    var lastMessageText: String {
        messages.sorted { $0.date > $1.date }.first?.displayText ?? "No messages yet"
    }
    var lastMessageTime: String {
        let sorted = messages.sorted { $0.date > $1.date }
        guard let last = sorted.first else { return "" }
        let f = DateFormatter()
        let cal = Calendar.current
        if cal.isDateInToday(last.date) { f.dateFormat = "HH:mm" }
        else if cal.isDateInYesterday(last.date) { return "Yesterday" }
        else { f.dateFormat = "dd/MM" }
        return f.string(from: last.date)
    }
}

extension String {
    func getInitials() -> String {
        let words = split(separator: " ")
        guard let first = words.first?.first else { return "?" }
        if words.count > 1, let last = words.last?.first { return "\(first)\(last)".uppercased() }
        return String(first).uppercased()
    }
}
