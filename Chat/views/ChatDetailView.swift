import SwiftUI

struct ChatDetailView: View {
    let chat: Chat
    @ObservedObject var chatViewModel: ChatViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var messageText = ""
    @State private var scrollProxy: ScrollViewProxy?
    @Environment(\.presentationMode) var presentationMode
    @FocusState private var isMessageFieldFocused: Bool
    @State private var gradientAnimation = false
    
    // Moving color sets
    private let gradientColors1: [Color] = [
        Color.blue.opacity(0.1),
        Color.purple.opacity(0.05),
        Color.pink.opacity(0.1)
    ]
    
    private let gradientColors2: [Color] = [
        Color.purple.opacity(0.1),
        Color.blue.opacity(0.05),
        Color.cyan.opacity(0.1)
    ]
    
    private let iconGradientColors: [Color] = [.blue, .purple, .pink]
    
    private var messages: [Message] {
        return chatViewModel.currentChat?.messages ?? chat.messages
    }
    
    // Universal current user detection
    private func isCurrentUser(message: Message) -> Bool {
        // Get current username with fallbacks
        let currentUsername = getCurrentUsername()
        
        // Normalize both names for comparison
        let messageNameNormalized = message.name.trimmingCharacters(in: .whitespaces).lowercased()
        let currentNameNormalized = currentUsername.trimmingCharacters(in: .whitespaces).lowercased()
        
        let isCurrent = messageNameNormalized == currentNameNormalized
        
        print("🔍 Message check: '\(message.name)' vs '\(currentUsername)' -> \(isCurrent)")
        
        return isCurrent
    }
    
    private func getCurrentUsername() -> String {
        // Try multiple sources for current username
        if let authUser = authViewModel.currentUser, !authUser.isEmpty {
            return authUser
        }
        
        if let storedUser = UserDefaults.standard.string(forKey: "currentUsername"), !storedUser.isEmpty {
            return storedUser
        }
        
        // Fallback - this should not happen if user is logged in
        return "UnknownUser"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages List with animated background
            ZStack {
                // Animated Background
                LinearGradient(
                    colors: gradientAnimation ? gradientColors1 : gradientColors2,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(messages) { message in
                                UniversalMessageBubble(
                                    message: message,
                                    isCurrentUser: isCurrentUser(message: message),
                                    gradientAnimation: gradientAnimation
                                )
                                .id(message.id)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                    }
                    .onAppear {
                        scrollProxy = proxy
                        scrollToBottom()
                        chatViewModel.startPollingForChat(chatId: chat.id)
                        
                        // Debug info
                        print("📱 Device: \(UIDevice.current.model)")
                        print("👤 Current user: \(getCurrentUsername())")
                        print("💬 Chat: \(chat.name)")
                        print("📨 Messages: \(messages.count)")
                    }
                    .onChange(of: messages.count) { _ in
                        scrollToBottom()
                    }
                    .onDisappear {
                        chatViewModel.stopPolling()
                    }
                }
            }
            
            // Message Input
            HStack(alignment: .bottom, spacing: 8) {
                Button(action: {}) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(
                            LinearGradient(
                                colors: iconGradientColors,
                                startPoint: gradientAnimation ? .top : .leading,
                                endPoint: gradientAnimation ? .bottom : .trailing
                            )
                        )
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: gradientAnimation)
                }
                
                HStack {
                    TextField("Message", text: $messageText, axis: .vertical)
                        .focused($isMessageFieldFocused)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemBackground))
                        .cornerRadius(20)
                }
                .background(Color(.systemBackground))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1
                        )
                )
                
                Button {
                    sendMessage()
                } label: {
                    if messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Image(systemName: "mic.circle.fill")
                            .font(.title2)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: iconGradientColors,
                                    startPoint: gradientAnimation ? .top : .leading,
                                    endPoint: gradientAnimation ? .bottom : .trailing
                                )
                            )
                            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: gradientAnimation)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    colors: [Color(.systemGray6).opacity(0.9), Color(.systemGray6).opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack {
                    Text(chat.name)
                        .font(.headline)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    Text("online")
                        .font(.caption)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
            }
        }
        .onAppear {
            chatViewModel.loadChat(chatId: chat.id)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isMessageFieldFocused = true
            }
            
            // Start gradient animation
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                gradientAnimation.toggle()
            }
        }
    }
    
    private func sendMessage() {
        let trimmedMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return }
        
        chatViewModel.sendMessage(trimmedMessage, chatId: chat.id)
        messageText = ""
    }
    
    private func scrollToBottom() {
        guard !messages.isEmpty else { return }
        
        if let lastMessage = messages.last {
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.3)) {
                    scrollProxy?.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
        }
    }
}

// Universal Message Bubble with gradient colors
struct UniversalMessageBubble: View {
    let message: Message
    let isCurrentUser: Bool
    let gradientAnimation: Bool
    
    private let iconGradientColors: [Color] = [.blue, .purple, .pink]
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if !isCurrentUser {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 2) {
                // Message content with gradient background
                HStack(alignment: .bottom, spacing: 6) {
                    if isCurrentUser {
                        messageTimeView
                    }
                    
                    Text(message.text)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(bubbleBackground)
                        .foregroundColor(bubbleForeground)
                        .cornerRadius(12)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    if !isCurrentUser {
                        messageTimeView
                    }
                }
            }
            
            if isCurrentUser {
                Spacer(minLength: 50)
            }
        }
        .padding(.horizontal, 4)
    }
    
    private var bubbleBackground: some View {
        Group {
            if isCurrentUser {
                // Current user - gradient background
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                // Other user - system gray with subtle gradient
                LinearGradient(
                    colors: [Color(.systemGray5), Color(.systemGray4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
    
    private var bubbleForeground: Color {
        isCurrentUser ? .white : .primary
    }
    
    private var messageTimeView: some View {
        Text(message.formattedTime)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(
                LinearGradient(
                    colors: [.gray, .gray.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }
}
