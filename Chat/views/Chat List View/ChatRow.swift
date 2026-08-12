import SwiftUI

// MARK: - ChatRow (WhatsApp-style)

struct ChatRow: View {
    let chat: ChatEntity
    @ObservedObject var chatViewModel: ChatViewModel

    private let primaryColor: Color = .jawabiPrimary

    private var chatId: Int { chat.chatId }
    private var liveUnreadCount: Int { chat.unreadCount }
    private var liveIsOnline: Bool {
        chat.participants.first?.isOnline
        ?? chatViewModel.userStatuses[chat.title]
        ?? false
    }
    private var liveName: String { chat.title }
    private var livePictureUrl: String {
        let base = "http://158.220.90.131:8444"
        guard let url = chat.avatarUrl, !url.isEmpty else {
            return "\(base)/uploads/users/default.png"
        }
        if url.hasPrefix("http") { return url }
        return base + url
    }
    private var liveLastMessageTime: String {
        guard let date = chat.lastMessageDate else { return "" }
        return ServerDateParser.formattedPreview(from: date)
    }
    private var isTyping: Bool { chatViewModel.getTypingStatus(for: chatId) != nil }
    private var liveLastMessagePreview: String {
        if let typingUser = chatViewModel.getTypingStatus(for: chatId) {
            return "\(typingUser) is typing..."
        }
        return chat.lastMessagePreview ?? ""
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                avatarView
                    .frame(width: 52, height: 52)

                if !chat.isGroup && liveIsOnline {
                    Circle()
                        .fill(Color(.systemBackground))
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .fill(Color.jawabiOnline)
                                .frame(width: 12, height: 12)
                        )
                        .offset(x: 2, y: 2)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(liveName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Spacer()

                    Text(liveLastMessageTime)
                        .font(.system(size: 12))
                        .foregroundColor(liveUnreadCount > 0 ? primaryColor : .secondary)
                }

                HStack(alignment: .top) {
                    Group {
                        if isTyping {
                            Text(liveLastMessagePreview)
                                .foregroundColor(primaryColor)
                        } else {
                            Text(liveLastMessagePreview)
                                .foregroundColor(liveUnreadCount > 0 ? .primary.opacity(0.75) : .secondary)
                                .fontWeight(liveUnreadCount > 0 ? .medium : .regular)
                        }
                    }
                    .font(.system(size: 14))
                    .lineLimit(1)

                    Spacer()

                    if liveUnreadCount > 0 {
                        Text(liveUnreadCount > 99 ? "99+" : "\(liveUnreadCount)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, liveUnreadCount > 9 ? 6 : 0)
                            .frame(minWidth: 20, minHeight: 20)
                            .background(
                                Capsule()
                                    .fill(primaryColor)
                            )
                    }
                }
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    // MARK: - Avatar

    @ViewBuilder
    private var avatarView: some View {
        let hasImage = !livePictureUrl.contains("default.png")
        let avatarColor = primaryColor

        if hasImage {
            AsyncImage(url: URL(string: livePictureUrl)) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                        .clipShape(Circle())
                default:
                    fallbackAvatar(color: avatarColor, isGroup: chat.isGroup)
                }
            }
        } else {
            fallbackAvatar(color: avatarColor, isGroup: chat.isGroup)
        }
    }

    private func fallbackAvatar(color: Color, isGroup: Bool) -> some View {
        Circle()
            .fill(color)
            .overlay(
                Group {
                    if isGroup {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.9))
                    } else if let first = liveName.first {
                        Text(String(first).uppercased())
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            )
    }

    // MARK: - Typing dots (available for use in the row if/when needed)

    struct TypingDotsView: View {
        let primaryColor: Color
        @State private var animationPhase = 0

        var body: some View {
            HStack(spacing: 3) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(primaryColor)
                        .frame(width: 5, height: 5)
                        .opacity(animationPhase == index ? 1.0 : 0.4)
                        .scaleEffect(animationPhase == index ? 1.2 : 0.8)
                }
            }
            .onReceive(Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()) { _ in
                animationPhase = (animationPhase + 1) % 3
            }
        }
    }
}