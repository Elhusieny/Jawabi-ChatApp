import SwiftUI

// MARK: - ChatListView (WhatsApp-style)

struct ChatListView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var chatViewModel = ChatViewModel()
    @State private var showingNewChat = false
    @State private var showingCreateRoom = false
    @State private var showingProfile = false
    @State private var showingSettings = false
    @State private var searchText = ""
    @State private var gradientAnimation = false
    @EnvironmentObject var profilePictureVM: ProfilePictureViewModel
    @State private var newChatAlert: (isPresented: Bool, chatName: String) = (false, "")
    @State private var isNavigatingToChat = false
    @State private var selectedChatId: Int?
    @State private var navigationPath = NavigationPath()

    private let primary = Color(hex: "#7373d2")
    private let primarySoft = Color(hex: "#9d73d2")
    private let accent = Color(hex: "#d273a3")
    @State private var pendingChatIdFromNotification: Int?
    @StateObject private var navigationManager = NavigationManager.shared

    var filteredChats: [Chat] {
        guard !searchText.isEmpty else { return chatViewModel.chats }
        return chatViewModel.chats.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.messages.last?.displayText.localizedCaseInsensitiveContains(searchText) == true
        }
    }

    var body: some View {
        NavigationStack(path: $navigationManager.navigationPath) {
            ZStack(alignment: .bottomTrailing) {
                // Plain system background — WhatsApp uses clean white/dark
                Color(.systemBackground).ignoresSafeArea()

                VStack(spacing: 0) {
                    if chatViewModel.chats.isEmpty {
                        emptyStateView
                    } else {
                        chatListContent
                    }
                }

                // WhatsApp-style FAB
                fabButton
            }
            
            .navigationDestination(for: Int.self, destination: chatDestination)

            .navigationBarTitleDisplayMode(.inline)
           .toolbar { toolbarContent }
           .toolbar {
               ToolbarItem(placement: .navigationBarLeading) {
                   Text("Jawabi")
                       .font(.largeTitle)
                       .fontWeight(.bold)
                       .foregroundStyle(
                           LinearGradient(
                               colors: [primary, primarySoft, accent],
                               startPoint: .leading,
                               endPoint: .trailing
                           )
                       )
                       .padding(.leading, 4)
               }
           }
            .searchable(text: $searchText, prompt: "Search chats...")
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
            .onAppear {
                print("📋 ChatListView appeared")
                chatViewModel.loadSavedChats()
                chatViewModel.loadAllUsers()
                
                // Process pending notification if chats are loaded
                if let pendingChatId = pendingChatIdFromNotification {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if chatViewModel.chats.contains(where: { $0.id == pendingChatId }) {
                            print("🎯 Processing pending notification to chat: \(pendingChatId)")
                            navigationPath.append(pendingChatId)
                            pendingChatIdFromNotification = nil
                        } else {
                            print("⚠️ Pending chat \(pendingChatId) not found in loaded chats")
                            // Fetch and try again
                            chatViewModel.fetchAllChatsFromServer()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                if chatViewModel.chats.contains(where: { $0.id == pendingChatId }) {
                                    navigationPath.append(pendingChatId)
                                    pendingChatIdFromNotification = nil
                                }
                            }
                        }
                    }
                }
            }
            .environmentObject(navigationManager)
                   .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToChatDetail"))) { notification in
                       print("📩 ChatListView received navigation request")
                       
                       guard let chatId = notification.userInfo?["chatId"] as? Int else {
                           print("❌ No chatId")
                           return
                       }
                       
                       print("🎯 Navigating to chat: \(chatId)")
                       
                       // Method 1: Use NavigationManager
                       DispatchQueue.main.async {
                           // Force a small delay to ensure the view is ready
                           DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                               navigationManager.navigateToChat(chatId: chatId)
                               
                               // Also try direct navigation
                               if !navigationManager.navigationPath.isEmpty {
                                   print("✅ Navigation path updated")
                               } else {
                                   print("⚠️ Navigation path empty, retrying...")
                                   // Retry after a delay
                                   DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                       navigationManager.navigationPath.append(chatId)
                                   }
                               }
                           }
                       }
                   }
               
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ChatListShouldRefresh"))) { _ in
                chatViewModel.fetchAllChatsFromServer()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ChatMembersUpdated"))) { _ in
                chatViewModel.fetchAllChatsFromServer()
            }
            .alert("New Chat", isPresented: $newChatAlert.isPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("You have a new chat with \(newChatAlert.chatName)")
            }
            .alert("Error", isPresented: .constant(chatViewModel.errorMessage != nil)) {
                Button("OK", role: .cancel) { chatViewModel.errorMessage = nil }
            } message: {
                Text(chatViewModel.errorMessage ?? "Unknown error")
            }
        }
        .accentColor(primary)
 }
    @ViewBuilder
    private func chatDestination(for chatId: Int) -> some View {
        if let chat = chatViewModel.chats.first(where: { $0.id == chatId }) {
            ChatDetailView(chat: chat, chatViewModel: chatViewModel)
                .onAppear {
                    print("✅ ChatDetailView opened for chat: \(chatId)")
                    pendingChatIdFromNotification = nil
                }
        } else {
            // Show loading while chat is being fetched
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Loading chat...")
                        .foregroundColor(.secondary)
                }
            }
            .onAppear {
                print("⏳ ChatDetailView loading for chat: \(chatId)")
                // Load the specific chat
                chatViewModel.loadChat(chatId: chatId)
                
                // Fetch all chats
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    chatViewModel.fetchAllChatsFromServer()
                }
            }
        }
    }
    // Custom title view with gradient
      private var gradientTitle: some View {
          Text("Jawabi")
              .font(.largeTitle)
              .fontWeight(.bold)
              .foregroundStyle(
                  LinearGradient(
                      colors: [primary, primarySoft, accent],
                      startPoint: .leading,
                      endPoint: .trailing
                  )
              )
      }


    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
//        ToolbarItem(placement: .navigationBarLeading) {
//            Button { showingProfile = true } label: {
//                profileAvatar
//            }
//        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button {
                      showingProfile = true
                  } label: {
                      Label("My Profile", systemImage: "person.circle")
                  }
                Button { showingCreateRoom = true } label: {
                    Label("New Group", systemImage: "person.2")
                }
                Button { showingSettings = true } label: {
                    Label("Settings", systemImage: "gear")
                }
                Divider()
                Button {
                    if let url = URL(string: "mailto:support@yourapp.com") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Send Feedback", systemImage: "envelope")
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.title3)
                    .foregroundStyle(primary)
            }
        }
    }

    // MARK: - Profile Avatar (leading toolbar)

    private var profileAvatar: some View {
        Circle()
            .fill(LinearGradient(colors: [primary, primarySoft], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 32, height: 32)
            .overlay(
                Text(String((authViewModel.currentUser ?? "U").prefix(1)).uppercased())
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            )
    }

    // MARK: - FAB

    // MARK: - FAB (WhatsApp-style Plus with Chat)

    private var fabButton: some View {
        Button {
            guard UserDefaults.standard.string(forKey: "authToken") != nil else { return }
            showingNewChat = true
            chatViewModel.loadAllUsers(forceRefresh: false)
        } label: {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [primary, primarySoft],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 58, height: 58)
                    .shadow(color: primary.opacity(0.4), radius: 12, x: 0, y: 6)
                
                // WhatsApp-style: Plus icon inside a chat bubble
                ZStack {
                    Image(systemName: "message.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                    
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .background(
                            Circle()
                                .fill(LinearGradient(
                                    colors: [primary, primarySoft],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
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
            ForEach(filteredChats, id: \.id) { chat in
                ZStack {
                    NavigationLink(
                        destination: ChatDetailView(chat: chat, chatViewModel: chatViewModel)
                            .onAppear { selectedChatId = chat.id; isNavigatingToChat = true }
                            .onDisappear { isNavigatingToChat = false },
                        tag: chat.id,
                        selection: $selectedChatId
                    ) {
                        EmptyView()
                    }
                    .opacity(0)

                    ChatRow(chat: chat, primaryColor: primary, chatViewModel: chatViewModel)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                .listRowSeparatorTint(Color(.systemGray5))
            }
        }
        .listStyle(.plain)
        .onAppear { isNavigatingToChat = false }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [primary.opacity(0.12), primarySoft.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 120, height: 120)

                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(LinearGradient(
                        colors: [primary, primarySoft],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
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

// MARK: - ChatRow (WhatsApp-style)

struct ChatRow: View {
    let chat: Chat
    let primaryColor: Color
    @ObservedObject var chatViewModel: ChatViewModel

    private var primarySoft: Color { Color(hex: "#9d73d2") }

    private var liveChat: Chat? { chatViewModel.chats.first(where: { $0.id == chat.id }) }
    private var liveUnreadCount: Int { liveChat?.unreadCount ?? chat.unreadCount }
    private var liveIsOnline: Bool { liveChat?.isOnline ?? chat.isOnline }
    private var liveName: String { liveChat?.name ?? chat.name }
    private var livePictureUrl: String { liveChat?.fullPictureUrl ?? chat.fullPictureUrl }
    private var liveLastMessageTime: String { liveChat?.lastMessageTime ?? chat.lastMessageTime }
    private var isTyping: Bool { chatViewModel.getTypingStatus(for: chat.id) != nil }
    private var liveLastMessagePreview: String {
        if let typingUser = chatViewModel.getTypingStatus(for: chat.id) {
            return "\(typingUser) is typing..."
        }
        return liveChat?.lastMessageText ?? chat.lastMessageText
    }

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack(alignment: .bottomTrailing) {
                avatarView
                    .frame(width: 52, height: 52)

                if chat.type == 1 && liveIsOnline {
                    Circle()
                        .fill(Color(.systemBackground))
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .fill(Color(hex: "#25D366")) // WhatsApp green
                                .frame(width: 12, height: 12)
                        )
                        .offset(x: 2, y: 2)
                }
            }

            // Text content
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
                                    .fill(LinearGradient(
                                        colors: [primaryColor, primarySoft],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
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
        let isGroup = chat.type != 1
        let hasImage = !livePictureUrl.isEmpty && !livePictureUrl.contains("default.png")
        let gradColors = isGroup
            ? [Color(hex: "#73d2a3"), Color(hex: "#9d73d2")]
            : [primaryColor, primarySoft]

        if hasImage {
            AsyncImage(url: URL(string: livePictureUrl)) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                        .clipShape(Circle())
                default:
                    fallbackAvatar(colors: gradColors, isGroup: isGroup)
                }
            }
        } else {
            fallbackAvatar(colors: gradColors, isGroup: isGroup)
        }
    }

    private func fallbackAvatar(colors: [Color], isGroup: Bool) -> some View {
        Circle()
            .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
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
}

// MARK: - Typing dots (unchanged)

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

// MARK: - Extensions (unchanged)

extension Chat {
    var lastMessageDate: Date {
        messages.sorted { $0.date > $1.date }.first?.date ?? Date.distantPast
    }
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

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a,r,g,b) = (255,(int>>8)*17,(int>>4 & 0xF)*17,(int & 0xF)*17)
        case 6: (a,r,g,b) = (255,int>>16,int>>8 & 0xFF,int & 0xFF)
        case 8: (a,r,g,b) = (int>>24,int>>16 & 0xFF,int>>8 & 0xFF,int & 0xFF)
        default: (a,r,g,b) = (1,1,1,0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
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

// Add this new view to handle loading:
struct ChatDetailLoadingView: View {
    let chatId: Int
    @ObservedObject var chatViewModel: ChatViewModel
    
    var body: some View {
        if let chat = chatViewModel.chats.first(where: { $0.id == chatId }) {
            ChatDetailView(chat: chat, chatViewModel: chatViewModel)
        } else {
            ProgressView("Loading chat...")
                .onAppear {
                    // Load the specific chat
                    chatViewModel.loadChat(chatId: chatId)
                    chatViewModel.fetchAllChatsFromServer()
                }
        }
    }
}
