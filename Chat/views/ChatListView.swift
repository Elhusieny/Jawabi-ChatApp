import SwiftUI

struct ChatListView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var chatViewModel = ChatViewModel() // Keep as StateObject
    @State private var showingNewChat = false
    @State private var showingCreateRoom = false
    @State private var showingProfile = false
    @State private var showingSearch = false
    @State private var searchText = ""
    @State private var gradientAnimation = false
    @State private var refreshID = UUID()
    @State private var lastUpdateTime = Date()
    
    // Add this state to track new chats
    @State private var newChatAlert: (isPresented: Bool, chatName: String) = (false, "")
    
    // ADD THIS: Track navigation to prevent duplicate navigation
    @State private var isNavigatingToChat = false
    @State private var selectedChatId: Int?
    
    @State private var forceUpdate = false
    
    // Define the main color as static computed properties
    private var primaryColor: Color { Color(hex: "#7373d2") }
    private var primaryColorLight: Color { primaryColor.opacity(0.2) }
    private var primaryColorDark: Color { primaryColor.opacity(0.8) }
    
    // Computed gradient colors
    private var gradientColors1: [Color] {
        [
            primaryColor.opacity(0.1),
            Color(hex: "#9d73d2").opacity(0.05),
            Color(hex: "#d273a3").opacity(0.1)
        ]
    }
    
    private var gradientColors2: [Color] {
        [
            Color(hex: "#9d73d2").opacity(0.1),
            primaryColor.opacity(0.05),
            Color(hex: "#73d2b8").opacity(0.1)
        ]
    }
    
    private var iconGradientColors: [Color] {
        [primaryColor, Color(hex: "#9d73d2"), Color(hex: "#d273a3")]
    }
    
    var filteredChats: [Chat] {
        if searchText.isEmpty {
            return chatViewModel.chats
        } else {
            return chatViewModel.chats.filter { chat in
                chat.name.localizedCaseInsensitiveContains(searchText) ||
                chat.messages.last?.text.localizedCaseInsensitiveContains(searchText) == true
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Animated Background
                LinearGradient(
                    colors: gradientAnimation ? gradientColors1 : gradientColors2,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .onAppear {
                    withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                        gradientAnimation.toggle()
                    }
                }
                if chatViewModel.chats.isEmpty {
                                 emptyStateView
                             } else {
                                 chatListView
                                     .id(refreshID)
                                     .id(forceUpdate) // Force refresh when this changes
                             }
                         }
            .navigationTitle("Chats")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    profileButton
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        searchButton
                        menuButton
                    }
                }
            }
            .searchable(text: $searchText, isPresented: $showingSearch, prompt: "Search chats...")
            .sheet(isPresented: $showingNewChat) {
                NewChatView(chatViewModel: chatViewModel, isPresented: $showingNewChat)
            }
            .sheet(isPresented: $showingCreateRoom) {
                CreateRoomView()
            }
            .sheet(isPresented: $showingProfile) {
                ProfileView(authViewModel: authViewModel, isPresented: $showingProfile)
            }
            .onAppear {
                           chatViewModel.loadSavedChats()
                           // ⚠️ Comment out notification observer - we're using @Published
                           // setupChatListObservers()
                           print("📱 ChatListView appeared with \(chatViewModel.chats.count) chats")
                       }
                       // FIXED: Watch for ANY changes to chats array
                       .onChange(of: chatViewModel.chats) { newChats in
                           refreshID = UUID()
                           forceUpdate.toggle()
                           lastUpdateTime = Date()
                           print("🔄 Chat list CHANGED - now has \(newChats.count) chats")
                           
                           // Debug: Print unread counts
                           for chat in newChats {
                               if chat.unreadCount > 0 {
                                   print("📢 Chat \(chat.name) has \(chat.unreadCount) unread messages")
                               }
                           }
                       }
                       // FIXED: Also watch for chatsUpdated timestamp
                       .onChange(of: chatViewModel.chatsUpdated) { _ in
                           print("🔄 chatsUpdated triggered UI refresh")
                           refreshID = UUID()
                           forceUpdate.toggle()
                       }
            // Optional: Alert for new chats
            .alert("New Chat", isPresented: $newChatAlert.isPresented) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("You have a new chat with \(newChatAlert.chatName)")
            }
            // ADD ALERT FOR ERRORS
            .alert("Error", isPresented: .constant(chatViewModel.errorMessage != nil)) {
                Button("OK", role: .cancel) {
                    chatViewModel.errorMessage = nil
                }
            } message: {
                Text(chatViewModel.errorMessage ?? "Unknown error")
            }
        }
        .accentColor(primaryColor)
    }
    
    private func setupChatListObservers() {
        // Set up observer for chat list refresh notifications
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ChatListShouldRefresh"),
            object: nil,
            queue: .main
        ) { notification in
            refreshID = UUID()
            lastUpdateTime = Date()
            
            if let chatId = notification.userInfo?["chatId"] as? Int {
                print("🔄 Chat list refreshed for chat \(chatId)")
            } else {
                print("🔄 Chat list refreshed generally")
            }
        }
    }
    
    // MARK: - Subviews
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "message.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: iconGradientColors,
                        startPoint: gradientAnimation ? .topLeading : .bottomLeading,
                        endPoint: gradientAnimation ? .bottomTrailing : .topTrailing
                    )
                )
                .symbolRenderingMode(.hierarchical)
                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: gradientAnimation)
            
            VStack(spacing: 8) {
                Text("No Chats Yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [primaryColor, Color(hex: "#9d73d2")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("Start chatting by creating a new chat or group room")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            VStack(spacing: 12) {
                Button {
                    showingNewChat = true
                    chatViewModel.loadAllUsers()
                } label: {
                    HStack {
                        Image(systemName: "message.fill")
                            .foregroundStyle(.white)
                        
                        Text("New Chat")
                            .foregroundColor(.white)
                    }
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [primaryColor, Color(hex: "#9d73d2")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(25)
                    .shadow(color: primaryColor.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                
                Button {
                    showingCreateRoom = true
                } label: {
                    HStack {
                        Image(systemName: "person.2.fill")
                            .foregroundStyle(.white)
                        
                        Text("Create Room")
                            .foregroundColor(.white)
                    }
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "#73d2a3"), primaryColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(25)
                    .shadow(color: Color(hex: "#73d2a3").opacity(0.3), radius: 8, x: 0, y: 4)
                }
            }
            .padding(.top, 10)
        }
    }
    
    // UPDATE ChatListView to pass chatViewModel to ChatRow
    // In ChatListView's chatListView computed property:

    private var chatListView: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(filteredChats, id: \.id) { chat in
                    NavigationLink(
                        destination: ChatDetailView(chat: chat, chatViewModel: chatViewModel)
                            .onAppear {
                                selectedChatId = chat.id
                                isNavigatingToChat = true
                            }
                            .onDisappear {
                                isNavigatingToChat = false
                            },
                        tag: chat.id,
                        selection: $selectedChatId
                    ) {
                        ChatRow(
                            chat: chat,
                            gradientAnimation: gradientAnimation,
                            primaryColor: primaryColor,
                            chatViewModel: chatViewModel  // ADD THIS
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(
                        TapGesture()
                            .onEnded {
                                print("📱 Navigating to chat \(chat.id): \(chat.name)")
                            }
                    )
                    
                    Divider()
                        .padding(.leading, 76)
                }
            }
            .background(Color(.systemBackground).opacity(0.8))
        }
        .background(Color.clear)
        .onAppear {
            isNavigatingToChat = false
        }
    }
    private var profileButton: some View {
        Button {
            showingProfile = true
        } label: {
            ZStack {
                Circle()
                    .fill(primaryColorLight)
                    .frame(width: 36, height: 36)
                
                Image(systemName: "person.circle.fill")
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: iconGradientColors,
                            startPoint: gradientAnimation ? .top : .leading,
                            endPoint: gradientAnimation ? .bottom : .trailing
                        )
                    )
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: gradientAnimation)
            }
        }
    }
    
    private var searchButton: some View {
        Button {
            showingSearch = true
        } label: {
            ZStack {
                Circle()
                    .fill(primaryColorLight)
                    .frame(width: 36, height: 36)
                
                Image(systemName: "magnifyingglass")
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: iconGradientColors,
                            startPoint: gradientAnimation ? .top : .leading,
                            endPoint: gradientAnimation ? .bottom : .trailing
                        )
                    )
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: gradientAnimation)
            }
        }
    }
    
    private var menuButton: some View {
        Menu {
            Button(action: {
                guard UserDefaults.standard.string(forKey: "authToken") != nil else {
                    showAlert(title: "Authentication Required",
                             message: "Please log in to create a new chat")
                    return
                }
                
                showingNewChat = true
                chatViewModel.loadAllUsers()
            }) {
                Label("New Chat", systemImage: "message")
            }
            
            Button(action: {
                guard UserDefaults.standard.string(forKey: "authToken") != nil else {
                    showAlert(title: "Authentication Required",
                             message: "Please log in to create a room")
                    return
                }
                showingCreateRoom = true
            }) {
                Label("Create Room", systemImage: "person.2")
            }
            Divider()
        } label: {
            ZStack {
                Circle()
                    .fill(primaryColorLight)
                    .frame(width: 36, height: 36)
                
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: iconGradientColors,
                            startPoint: gradientAnimation ? .top : .leading,
                            endPoint: gradientAnimation ? .bottom : .trailing
                        )
                    )
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: gradientAnimation)
            }
        }
    }
    
    // Add this helper function to show alerts
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        // Present the alert
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.1)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(primaryColor)
                
                Text("Loading...")
                    .font(.subheadline)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [primaryColor, Color(hex: "#9d73d2")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            .padding(24)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 10)
        }
    }
}

// Update the ChatRow struct in ChatListView
struct ChatRow: View {
    let chat: Chat
    let gradientAnimation: Bool
    let primaryColor: Color
    @ObservedObject var chatViewModel: ChatViewModel
    
    // FIXED: Add @State to force updates
    @State private var updateTrigger = false
    
    private var iconGradientColors: [Color] {
        [primaryColor, Color(hex: "#9d73d2"), Color(hex: "#d273a3")]
    }
    
    private var lastMessageTime: String {
        return chat.lastMessageTime
    }
    
    private var lastMessagePreview: String {
        // Check if someone is typing
        if let typingUser = chatViewModel.getTypingStatus(for: chat.id) {
            return "\(typingUser) is typing..."
        }
        return chat.lastMessageText
    }
    
    private var isTyping: Bool {
        chatViewModel.getTypingStatus(for: chat.id) != nil
    }
    
    private var isOnline: Bool {
        chatViewModel.isUserOnline(for: chat)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Profile Image with online indicator
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: URL(string: chat.fullPictureUrl)) { phase in
                    switch phase {
                    case .empty:
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [primaryColor.opacity(0.2), Color(hex: "#9d73d2").opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(primaryColor)
                            )
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 56, height: 56)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [primaryColor, Color(hex: "#9d73d2")],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                            )
                    case .failure:
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [primaryColor.opacity(0.2), Color(hex: "#9d73d2").opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.title2)
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: iconGradientColors,
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
                
                if chat.type == 1 {
                    Circle()
                        .fill(isOnline ? Color.green : Color.gray)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .stroke(Color(.systemBackground), lineWidth: 2.5)
                        )
                        .shadow(color: isOnline ? Color.green.opacity(0.5) : Color.clear, radius: 4)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(chat.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [primaryColor, Color(hex: "#9d73d2")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(lastMessageTime)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
                
                HStack(alignment: .top, spacing: 4) {
                    if isTyping {
                        HStack(spacing: 3) {
                            Text(lastMessagePreview)
                                .font(.system(size: 15))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [primaryColor, Color(hex: "#9d73d2")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .lineLimit(1)
                            
                            TypingDotsView(primaryColor: primaryColor)
                        }
                    } else {
                        // FIXED: Force bold when unread
                        Text(lastMessagePreview)
                            .font(.system(size: 15, weight: chat.unreadCount > 0 ? .semibold : .regular))
                            .foregroundColor(chat.unreadCount > 0 ? .primary : .secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    // FIXED: Show badge when unread
                    if chat.unreadCount > 0 {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [primaryColor, Color(hex: "#9d73d2")],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 22, height: 22)
                            
                            Text("\(min(chat.unreadCount, 99))")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .shadow(color: primaryColor.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            chat.unreadCount > 0
                ? Color(.systemBackground)
                : Color(.systemBackground).opacity(0.9)
        )
        .contentShape(Rectangle())
        // FIXED: Force update when chat data changes
        .onChange(of: chat.unreadCount) { newValue in
            updateTrigger.toggle()
            print("🔄 ChatRow unread changed to \(newValue) for \(chat.name)")
        }
        .onChange(of: chat.lastMessageText) { _ in
            updateTrigger.toggle()
        }
    }
}

// ADD THIS: Animated typing dots view
struct TypingDotsView: View {
    let primaryColor: Color
    @State private var animationPhase = 0
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [primaryColor, Color(hex: "#9d73d2")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 5, height: 5)
                    .opacity(animationPhase == index ? 1.0 : 0.4)
                    .scaleEffect(animationPhase == index ? 1.2 : 0.8)
            }
        }
        .onAppear {
            withAnimation(
                Animation.easeInOut(duration: 0.6)
                    .repeatForever(autoreverses: false)
            ) {
                animationPhase = 2
            }
        }
        .onReceive(Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()) { _ in
            animationPhase = (animationPhase + 1) % 3
        }
    }
}



extension Chat {
    var lastMessageDate: Date {
        // Sort messages by date to ensure we get the latest
        let sortedMessages = messages.sorted { $0.date > $1.date }
        return sortedMessages.first?.date ?? Date.distantPast
    }
    
    var lastMessageText: String {
        // Sort to get most recent message
        let sortedMessages = messages.sorted { $0.date > $1.date }
        return sortedMessages.first?.text ?? "No messages yet"
    }
    
    var lastMessageTime: String {
        // Sort to get most recent message
        let sortedMessages = messages.sorted { $0.date > $1.date }
        guard let lastMessage = sortedMessages.first else { return "" }
        
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(lastMessage.date) {
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: lastMessage.date)
        } else if calendar.isDateInYesterday(lastMessage.date) {
            return "Yesterday"
        } else {
            formatter.dateFormat = "dd/MM"
            return formatter.string(from: lastMessage.date)
        }
    }
}

// Add this Color extension for hex support
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

