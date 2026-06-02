//// MARK: - Universal Message Bubble
//
//import SwiftUI
//struct UniversalMessageBubble: View {
//    let message: Message
//    let isCurrentUser: Bool
//    let gradientAnimation: Bool
//    let chatViewModel: ChatViewModel
//    let chatId: Int
//    // Add this computed property to UniversalMessageBubble
//  
//    private let iconGradientColors: [Color] = [.blue, .purple, .pink]
//    
//    private var seenByUsers: [String] {
//        return message.seenBy ?? chatViewModel.getSeenStatus(for: message.id)
//    }
//    
//    private var isDelivered: Bool {
//        return chatViewModel.isMessageDelivered(message.id)
//    }
//    
//    private var isPartnerOnline: Bool {
//        if let liveChat = chatViewModel.chats.first(where: { $0.id == chatId }) {
//            return liveChat.isOnline
//        }
//        return false
//    }
//    
//    private enum CheckmarkState {
//        case sent
//        case delivered
//        case seen
//    }
//    
//    private var checkmarkState: CheckmarkState {
//        if !seenByUsers.isEmpty {
//            return .seen
//        }
//        if isDelivered || isPartnerOnline {
//            return .delivered
//        }
//        return .sent
//    }
//    
//    private var statusText: String {
//        switch checkmarkState {
//        case .sent: return "Sent"
//        case .delivered: return "Delivered"
//        case .seen: return "Seen"
//        }
//    }
//    // ✅ ADD THIS: MessageType enum
//    // Update the MessageType enum
//    private enum MessageType {
//        case text
//        case image(url: String, isBlocked: Bool)
//        case file(url: String, name: String, isBlocked: Bool)
//        case scanning(fileName: String) // ADD THIS
//        case voice(url: String)
//    }
//
//     
//    @State private var showStatusTooltip = false
//    private var isFileBlocked: Bool {
//           if let fileData = chatViewModel.fileStatusUpdates[message.id] {
//               return !fileData.isSafe
//           }
//           return false
//       }
//       
//
//    private var messageType: MessageType {
//        
//        // Add to your audio extensions list
//        let audioExtensions = [".m4a", ".mp3", ".mp4", ".aac", ".wav", ".ogg"]
//        let text = message.displayText.trimmingCharacters(in: .whitespaces)
//        if audioExtensions.contains(where: { text.lowercased().hasSuffix($0) }) ||
//           text.contains("/uploads/voice/") {
//            let fullUrl = buildFullUrl(text)
//            return .voice(url: fullUrl)
//        }
//        // Check for scanning messages first (using the new prefix)
//        if text.hasPrefix("SCANNING:") {
//            let fileName = text.replacingOccurrences(of: "SCANNING:", with: "")
//            return .scanning(fileName: fileName)
//        }
//        
//        // Check for uploading messages
//        if text.hasPrefix("UPLOADING:") {
//            let fileName = text.replacingOccurrences(of: "UPLOADING:", with: "")
//            return .scanning(fileName: fileName) // Use same scanning view for uploading
//        }
//        
//        
//        // Check if it's a regular web link FIRST (NOT a file)
//        if isRegularWebLink(text) {
//            print("🔗 Detected as REGULAR LINK: \(text)")
//            return .text  // Display as clickable text, not as file
//        }
//        
//        
//        // Check for scanning messages first
//           if message.displayText.hasPrefix("SCANNING:") || message.displayText.hasPrefix("UPLOADING:") {
//               let fileName = message.displayText.replacingOccurrences(of: "SCANNING:", with: "")
//                   .replacingOccurrences(of: "UPLOADING:", with: "")
//               return .scanning(fileName: fileName)
//           }
//           
//           // Use the typed field from backend
//           let url = message.fileUrl ?? message.displayText
//           
//           switch message.type {
//           case .voice:
//               return .voice(url: buildFullUrl(url))
//               
//               case .image:
//                   let blocked = message.isSafe == false && message.id > 0
//                                 && !message.displayText.hasPrefix("SCANNING:")
//                   return .image(url: buildFullUrl(url), isBlocked: blocked)
//
//           case .file:
//               let name = message.fileName ?? URL(string: buildFullUrl(url))?.lastPathComponent ?? url
//               return .file(url: buildFullUrl(url), name: name, isBlocked: message.isSafe == false)
//               
//           case .video:
//               // Handle video if needed
//               return .file(url: buildFullUrl(url), name: message.fileName ?? url, isBlocked: false)
//               
//           default:
//               // Check if it's a regular web link
//               if isRegularWebLink(message.displayText) {
//                   return .text
//               }
//               
//               // Check if it's an uploaded file (backward compatibility)
//               if isUploadedFile(message.displayText) {
//                   let fullUrl = buildFullUrl(message.displayText)
//                   let isBlocked = message.isSafe == false
//                   
//                   if isImageFile(message.displayText) {
//                       return .image(url: fullUrl, isBlocked: isBlocked)
//                   } else {
//                       let name = URL(string: fullUrl)?.lastPathComponent ?? message.displayText
//                       return .file(url: fullUrl, name: name, isBlocked: isBlocked)
//                   }
//               }
//               
//               return .text
//           }
//       }
//
//    // Add helper methods
//    private func isImageFile(_ text: String) -> Bool {
//        let imageExtensions = [".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp", ".tiff"]
//        return imageExtensions.contains { text.lowercased().hasSuffix($0) }
//    }
//
//
//    private func buildFullUrl(_ text: String) -> String {
//        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
//        
//        if cleaned.hasPrefix("http://") || cleaned.hasPrefix("https://") {
//            return cleaned
//        }
//        
//        let baseUrl = "http://158.220.90.131:8444"
//        
//        if cleaned.hasPrefix("/uploads") {
//            return "\(baseUrl)\(cleaned)"
//        }
//        
//        return "\(baseUrl)/uploads/\(cleaned)"
//    }
//       
//    
//    var body: some View {
//           HStack(alignment: .bottom, spacing: 8) {
//               if !isCurrentUser {
//                   Spacer(minLength: 50)
//               }
//               
//               messageContent
//               
//               if isCurrentUser {
//                   Spacer(minLength: 50)
//               }
//           }
//           .padding(.horizontal, 4)
//           .onAppear {
//               if !isCurrentUser {
//                   chatViewModel.markVisibleMessagesAsSeen(
//                       chatId: chatId,
//                       messageIds: [message.id]
//                   )
//               }
//           }
//           .onTapGesture {
//               showStatusTooltip = false
//           }
//       }
//    private func containsURL(_ text: String) -> Bool {
//        let detector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
//        let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
//        return !matches.isEmpty
//    }
//    // MARK: - Helper Functions for Link Detection
//
//    // In UniversalMessageBubble — isUploadedFile()
//    private func isUploadedFile(_ text: String) -> Bool {
//        let fileExtensions = [".pdf", ".doc", ".docx", ".txt", ".rtf", ".zip", ".rar",
//                              ".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp", ".tiff",
//                              ".m4a", ".mp3", ".aac", ".wav"] // ADD AUDIO TYPES
//        return fileExtensions.contains { text.lowercased().hasSuffix($0) }
//    }
//
//    private func isRegularWebLink(_ text: String) -> Bool {
//        // It's a regular web link if:
//        // 1. It starts with http:// or https://
//        // 2. AND it's NOT an uploaded file from our server
//        
//        guard text.hasPrefix("http://") || text.hasPrefix("https://") else {
//            return false
//        }
//        
//        // If it has a file extension, it's a file
//        if isUploadedFile(text) {
//            return false
//        }
//        
//        // Otherwise, it's a regular web link
//        return true
//    }
//    @ViewBuilder
//    private var messageContent: some View {
//        VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
//            switch messageType {
//            case .voice(let url):
//                VoiceMessageBubble(
//                    audioURL: url,
//                    isCurrentUser: isCurrentUser,
//                    duration: nil
//                )
//            case .text:
//                if message.displayText.hasPrefix("http://") || message.displayText.hasPrefix("https://") {
//                    // ✅ URL bubble with timestamp inside
//                    ZStack(alignment: .bottomTrailing) {
//                        ClickableLinkText(
//                            text: message.displayText,
//                            bubbleBackground: bubbleBackground,
//                            bubbleForeground: bubbleForeground
//                        )
//                        .contextMenu {
//                            Button(action: { UIPasteboard.general.string = message.displayText }) {
//                                Label("Copy Link", systemImage: "doc.on.doc")
//                            }
//                            if let url = URL(string: message.displayText) {
//                                Button(action: { UIApplication.shared.open(url) }) {
//                                    Label("Open in Browser", systemImage: "safari")
//                                }
//                            }
//                        }
//
//                        timestampView
//                            .padding(.trailing, 8)
////                            .padding(.bottom, 6)
//                    }
//                } else {
//                    // ✅ Text bubble with timestamp inside
//                    ZStack(alignment: .bottomTrailing) {
//                        Text(message.displayText + "          ")
//                            .padding(.horizontal, 12)
//                            .padding(.vertical, 8)
//                            .background(bubbleBackground)
//                            .foregroundColor(bubbleForeground)
//                            .cornerRadius(12)
//                            .fixedSize(horizontal: false, vertical: true)
//                            .contextMenu {
//                                Button(action: { UIPasteboard.general.string = message.displayText }) {
//                                    Label("Copy", systemImage: "doc.on.doc")
//                                }
//                            }
//
//                        timestampView
//                            .padding(.trailing, 8)
//                            .padding(.bottom, 6)
//                    }
//                }
//
//            case .image(let url, let isBlocked):
//                // ✅ Image with timestamp overlaid on bottom-right
//                ZStack(alignment: .bottomTrailing) {
//                    ImageMessageView(
//                        imageUrl: url,
//                        isCurrentUser: isCurrentUser,
//                        isBlocked: isBlocked
//                    )
//
//                    timestampView
//                        .padding(.trailing, 8)
//                        .padding(.bottom, 8)
//                        .background(
//                            Capsule()
//                                .fill(Color.black.opacity(0.35))
//                                .padding(.horizontal, -6)
//                                .padding(.vertical, -3)
//                        )
//                }
//
//            case .file(let url, let name, let isBlocked):
//                // ✅ File bubble with timestamp inside bottom-right
//                ZStack(alignment: .bottomTrailing) {
//                    FileMessageView(
//                        fileUrl: url,
//                        fileName: name,
//                        isCurrentUser: isCurrentUser,
//                        bubbleForeground: bubbleForeground,
//                        isBlocked: isBlocked
//                    )
//
//                    timestampView
//                        .padding(.trailing, 8)
//                        .padding(.bottom, 8)
//                }
//
//            case .scanning(let fileName):
//                // ✅ Scanning bubble with timestamp inside
//                ZStack(alignment: .bottomTrailing) {
//                    ScanningMessageView(
//                        fileName: fileName,
//                        isCurrentUser: isCurrentUser
//                    )
//
//                    timestampView
//                        .padding(.trailing, 8)
//                        .padding(.bottom, 8)
//                }
//            }
//        }
//    }
//
//    // ✅ Reusable timestamp + checkmark view
//    @ViewBuilder
//    private var timestampView: some View {
//        HStack(spacing: 3) {
//            Text(message.formattedTime)
//                .font(.system(size: 11, weight: .medium))
//                .foregroundColor(isCurrentUser ? .white.opacity(0.7) : .gray)
//
//            if isCurrentUser {
//                checkmarkView
//            }
//        }
//    }
//       private var bubbleBackground: LinearGradient {
//           if isCurrentUser {
//               return LinearGradient(
//                   colors: [.blue, .purple],
//                   startPoint: .topLeading,
//                   endPoint: .bottomTrailing
//               )
//           } else {
//               return LinearGradient(
//                   colors: [Color(.systemGray5), Color(.systemGray4)],
//                   startPoint: .topLeading,
//                   endPoint: .bottomTrailing
//               )
//           }
//       }
//       
//       private var bubbleForeground: Color {
//           isCurrentUser ? .white : .primary
//       }
//    
//    @ViewBuilder
//    private var seenIndicatorButton: some View {
//        Button(action: {
//            showStatusTooltip.toggle()
//        }) {
//            seenIndicatorView
//        }
//        .buttonStyle(.plain)
//        .overlay(
//            Group {
//                if showStatusTooltip {
//                    statusTooltipView
//                }
//            },
//            alignment: .bottom
//        )
//    }
//    
//    @ViewBuilder
//    private var seenIndicatorView: some View {
//        HStack(spacing: 4) {
//            Text(message.formattedTime)
//                .font(.system(size: 11, weight: .medium))
//                .foregroundColor(.gray)
//
//            if isCurrentUser {
//                checkmarkView
//            }
//        }
//        .padding(.horizontal, 4)
//    }
//    
//    @ViewBuilder
//    private var checkmarkView: some View {
//        HStack(spacing: -4) {
//            switch checkmarkState {
//            case .sent:
//                Image(systemName: "checkmark")
//                    .font(.system(size: 11))
//                    .foregroundColor(.gray)
//                
//            case .delivered:
//                Image(systemName: "checkmark")
//                    .font(.system(size: 11))
//                    .foregroundColor(.gray)
//                
//                Image(systemName: "checkmark")
//                    .font(.system(size: 11))
//                    .foregroundColor(.gray)
//                    .offset(x: -3)
//                
//            case .seen:
//                Image(systemName: "checkmark")
//                    .font(.system(size: 11))
//                    .foregroundColor(.blue)
//                
//                Image(systemName: "checkmark")
//                    .font(.system(size: 11))
//                    .foregroundColor(.blue)
//                    .offset(x: -3)
//            }
//        }
//        .frame(width: checkmarkState == .sent ? 10 : 16, height: 10)
//    }
//    @ViewBuilder
//    private var statusTooltipView: some View {
//        VStack(spacing: 2) {
//            Text(statusText)
//                .font(.system(size: 10))
//                .padding(4)
//                .background(Color.black.opacity(0.7))
//                .foregroundColor(.white)
//                .cornerRadius(4)
//            
//            if !seenByUsers.isEmpty {
//                Text("Seen by:")
//                    .font(.system(size: 9))
//                    .padding(.top, 2)
//                
//                ForEach(seenByUsers, id: \.self) { user in
//                    Text(user)
//                        .font(.system(size: 9))
//                        .padding(2)
//                        .background(Color.black.opacity(0.5))
//                        .foregroundColor(.white)
//                        .cornerRadius(3)
//                }
//            }
//        }
//        .padding(6)
//        .background(Color.black.opacity(0.8))
//        .foregroundColor(.white)
//        .cornerRadius(6)
//        .padding(.bottom, 25)
//        .transition(.opacity)
//    }
//}
