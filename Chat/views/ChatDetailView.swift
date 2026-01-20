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
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    
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
        if let liveChat = chatViewModel.chats.first(where: { $0.id == chat.id }) {
            return liveChat.messages
        }
        return chat.messages
    }
    
    private var currentLiveChat: Chat? {
        chatViewModel.chats.first(where: { $0.id == chat.id })
    }
    
    private var typingUser: String? {
        chatViewModel.getTypingStatus(for: chat.id)
    }
    
    private func isCurrentUser(message: Message) -> Bool {
        let currentUsername = getCurrentUsername()
        let messageNameNormalized = message.name.trimmingCharacters(in: .whitespaces).lowercased()
        let currentNameNormalized = currentUsername.trimmingCharacters(in: .whitespaces).lowercased()
        
        return messageNameNormalized == currentNameNormalized ||
               messageNameNormalized == "you" ||
               (currentUsername.lowercased() == "test46" && messageNameNormalized == "you") ||
               (message.id < 0 && messageNameNormalized == currentNameNormalized)
    }
    
    private func getCurrentUsername() -> String {
        let sources = [
            "currentUsername",
            "userName",
            "userDisplayName",
            "username"
        ]
        
        for key in sources {
            if let value = UserDefaults.standard.string(forKey: key), !value.isEmpty {
                return value
            }
        }
        
        if let authUser = authViewModel.currentUser, !authUser.isEmpty {
            return authUser
        }
        
        return "UnknownUser"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
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
                                    gradientAnimation: gradientAnimation,
                                    chatViewModel: chatViewModel,
                                    chatId: chat.id
                                )
                                .id(String(describing: message.id))
                            }
                            
                            if let typingUser = typingUser {
                                TypingIndicatorBubble(
                                    userName: typingUser,
                                    gradientAnimation: gradientAnimation
                                )
                                .id("typing-indicator")
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                    }
                    .onAppear {
                        scrollProxy = proxy
                        scrollToBottom()
                        chatViewModel.startPollingForChat(chatId: chat.id)
                    }
                    .onChange(of: messages.count) { newCount in
                        scrollToBottom()
                    }
                    .onChange(of: typingUser) { _ in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            scrollToBottom()
                        }
                    }
                    .onChange(of: messages.map { $0.id }) { _ in
                        scrollToBottom()
                    }
                    .sheet(isPresented: $showingImagePicker) {
                        ImagePicker(image: $selectedImage)
                    }
                    .onChange(of: selectedImage) { newImage in
                        if let image = newImage {
                            chatViewModel.sendImageMessage(image, chatId: chat.id)
                            selectedImage = nil
                        }
                    }
                    .onDisappear {
                        chatViewModel.stopPolling()
                    }
                }
            }
            
            HStack(alignment: .bottom, spacing: 8) {
                Button(action: {
                    showingImagePicker = true
                }) {
                    Image(systemName: "photo.circle.fill")
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
                        .onChange(of: messageText) { newValue in
                            if !newValue.isEmpty {
                                chatViewModel.sendTypingIndicator(for: chat.id)
                            }
                        }
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
                    Text(currentLiveChat?.name ?? chat.name)
                        .font(.headline)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    if let typingUser = typingUser {
                        Text("typing...")
                            .font(.caption)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    } else if currentLiveChat?.isOnline == true || chat.isOnline {
                        Text("online")
                            .font(.caption)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.green, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    } else {
                        Text("offline")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .onAppear {
            chatViewModel.loadChat(chatId: chat.id)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isMessageFieldFocused = true
            }
            
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
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            scrollToBottom()
        }
    }
    
    private func scrollToBottom() {
        guard !messages.isEmpty else { return }
        
        let targetId: String? = typingUser != nil ? "typing-indicator" : (messages.last.map { String(describing: $0.id) })
        
        if let targetId = targetId {
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.3)) {
                    scrollProxy?.scrollTo(targetId, anchor: .bottom)
                }
            }
        }
    }
}

// Typing indicator bubble
struct TypingIndicatorBubble: View {
    let userName: String
    let gradientAnimation: Bool
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .bottom, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("\(userName) is typing")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 3) {
                            ForEach(0..<3) { index in
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.blue, .purple],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(width: 6, height: 6)
                                    .opacity(gradientAnimation ? 1.0 : 0.3)
                                    .animation(
                                        Animation.easeInOut(duration: 0.6)
                                            .repeatForever(autoreverses: true)
                                            .delay(Double(index) * 0.2),
                                        value: gradientAnimation
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [Color(.systemGray5), Color(.systemGray4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(12)
                }
            }
            
            Spacer(minLength: 50)
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Universal Message Bubble
struct UniversalMessageBubble: View {
    let message: Message
    let isCurrentUser: Bool
    let gradientAnimation: Bool
    let chatViewModel: ChatViewModel
    let chatId: Int
    
    private let iconGradientColors: [Color] = [.blue, .purple, .pink]
    
    private var seenByUsers: [String] {
        return message.seenBy ?? chatViewModel.getSeenStatus(for: message.id)
    }
    
    private var isDelivered: Bool {
        return chatViewModel.isMessageDelivered(message.id)
    }
    
    private var isPartnerOnline: Bool {
        if let liveChat = chatViewModel.chats.first(where: { $0.id == chatId }) {
            return liveChat.isOnline
        }
        return false
    }
    
    private enum MessageType {
        case text
        case image(url: String)
        case file(url: String, name: String)
    }
    
    private var messageType: MessageType {
        let text = message.text.trimmingCharacters(in: .whitespaces)
        
        // Check for image extensions
        if text.lowercased().hasSuffix(".jpg") ||
           text.lowercased().hasSuffix(".jpeg") ||
           text.lowercased().hasSuffix(".png") ||
           text.lowercased().hasSuffix(".gif") ||
           text.lowercased().hasSuffix(".webp") {
            
            // Build full URL properly
            let fullUrl: String
            if text.hasPrefix("http://") || text.hasPrefix("https://") {
                // Already a full URL
                fullUrl = text
            } else if text.hasPrefix("/uploads/") {
                // Relative path starting with /uploads/
                fullUrl = "http://158.220.90.131:8444\(text)"
            } else if text.hasPrefix("/") {
                // Any other relative path
                fullUrl = "http://158.220.90.131:8444\(text)"
            } else {
                // Just a filename
                fullUrl = "http://158.220.90.131:8444/uploads/\(text)"
            }
            
            return .image(url: fullUrl)
        }
        
        // Check for file extensions
        if text.contains(".pdf") ||
           text.contains(".doc") ||
           text.contains(".docx") ||
           text.contains(".txt") ||
           text.contains(".zip") ||
           text.contains(".rar") {
            
            // Build full URL properly
            let fullUrl: String
            if text.hasPrefix("http://") || text.hasPrefix("https://") {
                fullUrl = text
            } else if text.hasPrefix("/uploads/") {
                fullUrl = "http://158.220.90.131:8444\(text)"
            } else if text.hasPrefix("/") {
                fullUrl = "http://158.220.90.131:8444\(text)"
            } else {
                fullUrl = "http://158.220.90.131:8444/uploads/\(text)"
            }
            
            let fileName = URL(string: fullUrl)?.lastPathComponent ?? text
            return .file(url: fullUrl, name: fileName)
        }
        
        return .text
    }
    
    private enum CheckmarkState {
        case sent
        case delivered
        case seen
    }
    
    private var checkmarkState: CheckmarkState {
        if !seenByUsers.isEmpty {
            return .seen
        }
        if isDelivered || isPartnerOnline {
            return .delivered
        }
        return .sent
    }
    
    private var seenIndicator: some View {
        Group {
            if isCurrentUser {
                HStack(spacing: 4) {
                    Text(message.formattedTime)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.gray)
                    
                    HStack(spacing: -4) {
                        switch checkmarkState {
                        case .sent:
                            Image(systemName: "checkmark")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                            
                        case .delivered:
                            Image(systemName: "checkmark")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                                .offset(x: -3)
                            
                        case .seen:
                            Image(systemName: "checkmark")
                                .font(.system(size: 11))
                                .foregroundColor(.blue)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 11))
                                .foregroundColor(.blue)
                                .offset(x: -3)
                        }
                    }
                    .frame(width: checkmarkState == .sent ? 10 : 16, height: 10)
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 1)
            } else {
                Text(message.formattedTime)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
    }
    
    private var statusText: String {
        switch checkmarkState {
        case .sent: return "Sent"
        case .delivered: return "Delivered"
        case .seen: return "Seen"
        }
    }
    
    @State private var showStatusTooltip = false
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if !isCurrentUser {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 2) {
                HStack(alignment: .bottom, spacing: 6) {
                    if isCurrentUser {
                        Button(action: {
                            showStatusTooltip.toggle()
                        }) {
                            seenIndicator
                        }
                        .buttonStyle(.plain)
                        .overlay(
                            Group {
                                if showStatusTooltip {
                                    VStack(spacing: 2) {
                                        Text(statusText)
                                            .font(.system(size: 10))
                                            .padding(4)
                                            .background(Color.black.opacity(0.7))
                                            .foregroundColor(.white)
                                            .cornerRadius(4)
                                        
                                        if !seenByUsers.isEmpty {
                                            Text("Seen by:")
                                                .font(.system(size: 9))
                                                .padding(.top, 2)
                                            
                                            ForEach(seenByUsers, id: \.self) { user in
                                                Text(user)
                                                    .font(.system(size: 9))
                                                    .padding(2)
                                                    .background(Color.black.opacity(0.5))
                                                    .foregroundColor(.white)
                                                    .cornerRadius(3)
                                            }
                                        }
                                    }
                                    .padding(6)
                                    .background(Color.black.opacity(0.8))
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                                    .padding(.bottom, 25)
                                    .transition(.opacity)
                                }
                            },
                            alignment: .bottom
                        )
                    }
                    
                    Group {
                        switch messageType {
                        case .text:
                            Text(message.text)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(bubbleBackground)
                                .foregroundColor(bubbleForeground)
                                .cornerRadius(12)
                                .fixedSize(horizontal: false, vertical: true)
                                .contextMenu {
                                    Button(action: {
                                        UIPasteboard.general.string = message.text
                                    }) {
                                        Label("Copy", systemImage: "doc.on.doc")
                                    }
                                }
                            
                        case .image(let url):
                            ImageMessageView(
                                imageUrl: url,
                                isCurrentUser: isCurrentUser
                            )
                            
                        case .file(let url, let name):
                            FileMessageView(
                                fileUrl: url,
                                fileName: name,
                                isCurrentUser: isCurrentUser,
                                bubbleForeground: bubbleForeground
                            )
                        }
                    }
                    
                    if !isCurrentUser {
                        seenIndicator
                    }
                }
            }
            
            if isCurrentUser {
                Spacer(minLength: 50)
            }
        }
        .padding(.horizontal, 4)
        .onAppear {
            if !isCurrentUser {
                chatViewModel.markVisibleMessagesAsSeen(
                    chatId: chatId,
                    messageIds: [message.id]
                )
            }
        }
        .onTapGesture {
            showStatusTooltip = false
        }
    }
    
    private var bubbleBackground: LinearGradient {
        if isCurrentUser {
            return LinearGradient(
                colors: [.blue, .purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [Color(.systemGray5), Color(.systemGray4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var bubbleForeground: Color {
        isCurrentUser ? .white : .primary
    }
}

// MARK: - Image Message View
struct ImageMessageView: View {
    let imageUrl: String
    let isCurrentUser: Bool
    
    @State private var showFullScreen = false
    
    var body: some View {
        AsyncImage(url: URL(string: imageUrl)) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .frame(width: 200, height: 200)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .onAppear {
                        print("🖼️ Loading image from: \(imageUrl)")
                    }
                
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: 250, maxHeight: 300)
                    .clipped()
                    .cornerRadius(12)
                    .onTapGesture {
                        showFullScreen = true
                    }
                    .onAppear {
                        print("✅ Image loaded successfully: \(imageUrl)")
                    }
                
            case .failure(let error):
                VStack {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("Failed to load")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(width: 200, height: 200)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .onAppear {
                    print("❌ Image failed to load: \(imageUrl)")
                    print("   Error: \(error)")
                }
                
            @unknown default:
                EmptyView()
            }
        }
        .contextMenu {
            Button(action: {
                UIPasteboard.general.string = imageUrl
            }) {
                Label("Copy URL", systemImage: "doc.on.doc")
            }
            
            Button(action: {
                downloadImage()
            }) {
                Label("Save Image", systemImage: "square.and.arrow.down")
            }
        }
        .sheet(isPresented: $showFullScreen) {
            FullScreenImageView(imageUrl: imageUrl)
        }
    }
    
    private func downloadImage() {
        guard let url = URL(string: imageUrl) else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data, let image = UIImage(data: data) else { return }
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        }.resume()
    }
}

// MARK: - Full Screen Image
struct FullScreenImageView: View {
    let imageUrl: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                AsyncImage(url: URL(string: imageUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .failure:
                        VStack {
                            Image(systemName: "photo.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.white)
                            Text("Failed to load")
                                .foregroundColor(.white)
                        }
                    case .empty:
                        ProgressView()
                            .tint(.white)
                    @unknown default:
                        EmptyView()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

// MARK: - File Message View
struct FileMessageView: View {
    let fileUrl: String
    let fileName: String
    let isCurrentUser: Bool
    let bubbleForeground: Color
    
    private var fileExtension: String {
        (fileName as NSString).pathExtension.uppercased()
    }
    
    private var fileIcon: String {
        switch fileExtension {
        case "PDF": return "doc.fill"
        case "DOC", "DOCX": return "doc.text.fill"
        case "TXT": return "doc.text"
        case "ZIP", "RAR": return "doc.zipper"
        default: return "doc"
        }
    }
    
    private var bubbleBackground: LinearGradient {
        if isCurrentUser {
            return LinearGradient(
                colors: [.blue, .purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [Color(.systemGray5), Color(.systemGray4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: fileIcon)
                .font(.system(size: 32))
                .foregroundColor(isCurrentUser ? .white : .blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(fileName)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(2)
                
                Text(fileExtension)
                    .font(.system(size: 12))
                    .opacity(0.7)
            }
            
            Spacer()
            
            Button(action: openFile) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(isCurrentUser ? .white : .blue)
            }
        }
        .padding(12)
        .frame(maxWidth: 280)
        .background(bubbleBackground)
        .foregroundColor(bubbleForeground)
        .cornerRadius(12)
        .contextMenu {
            Button(action: {
                UIPasteboard.general.string = fileUrl
            }) {
                Label("Copy URL", systemImage: "doc.on.doc")
            }
            
            Button(action: openFile) {
                Label("Open File", systemImage: "arrow.down.circle")
            }
        }
    }
    
    private func openFile() {
        guard let url = URL(string: fileUrl) else { return }
        UIApplication.shared.open(url)
    }
}
