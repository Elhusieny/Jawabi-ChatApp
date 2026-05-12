import SwiftUI
import Combine
/// View that displays a detailed chat conversation with another user or group
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

    // Add this property to ChatDetailView
    @State private var uploadCancellable: AnyCancellable?
    @State private var showingFilePicker = false
    @State private var selectedFileURL: URL?
    @State private var fileData: Data?
    @State private var fileName: String = ""
    @State private var isUploadingFile = false

    // Add these with your other @State variables
    @State private var showingGroupInfo = false
    @State private var showingAddMembers = false
    @StateObject private var voiceRecorder = VoiceRecorderService()
    @State private var isRecordingVoice = false
    @State private var recordingStartURL: URL?
    
    
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
    
    // In ChatDetailView.swift - Update the messages computed property
    private var messages: [Message] {
        if let liveChat = chatViewModel.chats.first(where: { $0.id == chat.id }) {
            // Change to ASCENDING order (oldest first, newest last)
            return liveChat.messages.sorted { $0.date < $1.date }
        }
        return chat.messages.sorted { $0.date < $1.date }
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
               // Chat messages area
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
                               // Messages are now in ascending order (oldest to newest)
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
                       .onChange(of: messages.count) { _ in
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
                       // Add to your view to monitor uploads
                       .onReceive(chatViewModel.$fileStatusUpdates) { updates in
                           print("📡 File status updates: \(updates.count)")
                           for (messageId, data) in updates {
                               print("   - Message \(messageId): \(data.fileUrl) - \(data.isSafe ? "Safe" : "Blocked")")
                           }
                       }
                   }
               }
                            HStack(alignment: .bottom, spacing: 8) {
                              // File picker menu
                              Menu {
                                  Button(action: {
                                      showingImagePicker = true
                                  }) {
                                      Label("Photo Library", systemImage: "photo")
                                  }
                                  
                                  Button(action: {
                                      showDocumentPicker()
                                  }) {
                                      Label("Document", systemImage: "doc")
                                  }
                                  
                                  Button(action: {
                                      // For camera, you would need a separate image picker with .camera source
                                      showingImagePicker = true
                                  }) {
                                      Label("Camera", systemImage: "camera")
                                  }
                              } label: {
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
                              
                              // Message text field
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
                              

                                // RIGHT: voice button and send button with WhatsApp-style recording
                                if messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    && selectedFileURL == nil
                                    && !isRecordingVoice {
                                    
                                    // Voice button to start recording
                                    Button(action: {
                                        voiceRecorder.requestPermission { granted in
                                            guard granted else { return }
                                            do {
                                                try voiceRecorder.startRecording()
                                                withAnimation(.spring(response: 0.3)) {
                                                    isRecordingVoice = true
                                                }
                                            } catch {
                                                print("❌ Failed to start recording: \(error)")
                                            }
                                        }
                                    }) {
                                        Image(systemName: "mic.circle.fill")
                                            .font(.title2)
                                            .foregroundStyle(
                                                LinearGradient(
                                                    colors: [.blue, .purple],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                    }
                                    
                                } else if isRecordingVoice {
                                    // Show WhatsApp-style compact recording controls
                                    CompactRecordingView(
                                        recorder: voiceRecorder,
                                        onSend: { url in
                                            if let data = try? Data(contentsOf: url) {
                                                uploadFileWithSignalR(data: data, fileName: url.lastPathComponent)
                                            }
                                            withAnimation(.spring(response: 0.3)) {
                                                isRecordingVoice = false
                                            }
                                        },
                                        onCancel: {
                                            voiceRecorder.cancelRecording()
                                            withAnimation(.spring(response: 0.3)) {
                                                isRecordingVoice = false
                                            }
                                        }
                                    )
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                                    
                                } else {
                                    // Send button
                                    Button {
                                        if let fileURL = selectedFileURL, let data = fileData {
                                            sendFileMessage(data: data, fileName: fileName)
                                        } else {
                                            sendMessage()
                                        }
                                    } label: {
                                        if isUploadingFile {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                                .frame(width: 24, height: 24)
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
                                    .disabled(
                                        messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                        && selectedFileURL == nil
                                    )
                                }
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
        // In ChatDetailView.swift, add to toolbar
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if chat.type == 0 { // Group chat
                    Menu {
                        Button(action: {
                            // Navigate to group info
                            showingGroupInfo = true
                        }) {
                            Label("Group Info", systemImage: "info.circle")
                        }
                        
                        if chat.isCurrentUserAdmin {
                            Button(action: {
                                showingAddMembers = true
                            }) {
                                Label("Add Members", systemImage: "person.badge.plus")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingGroupInfo) {
            NavigationView {
                GroupInfoView(
                    chatViewModel: chatViewModel,
                    chat: chat
                )
            }
        }
        .sheet(isPresented: $showingAddMembers) {
            AddMembersView(
                chatId: chat.id,
                chatName: chat.name,
                existingMembers: chat.users.map { $0.userId }
            )
        }
                      .navigationBarTitleDisplayMode(.inline)
                      .navigationBarBackButtonHidden(false)
        // In ChatDetailView, update the navigation title:
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    // User/chat image
                    if let liveChat = currentLiveChat {
                        AsyncImage(url: URL(string: liveChat.fullPictureUrl)) { phase in
                            switch phase {
                            case .empty:
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Text(liveChat.name.getInitials())
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                                
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 30, height: 30)
                                    .clipShape(Circle())
                                
                            case .failure:
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Text(liveChat.name.getInitials())
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                                
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
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
                      .sheet(isPresented: $showingImagePicker) {
                          ImagePicker(image: $selectedImage)
                      }
                      .fileImporter(
                          isPresented: $showingFilePicker,
                          allowedContentTypes: [.item],
                          allowsMultipleSelection: false
                      ) { result in
                          handleFileSelection(result)
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
                  
                  private func showDocumentPicker() {
                      showingFilePicker = true
                  }
                  
                  private func handleFileSelection(_ result: Result<[URL], Error>) {
                      switch result {
                      case .success(let urls):
                          guard let url = urls.first else { return }
                          
                          do {
                              // Start accessing the security-scoped resource
                              guard url.startAccessingSecurityScopedResource() else {
                                  print("Failed to access security scoped resource")
                                  return
                              }
                              
                              defer { url.stopAccessingSecurityScopedResource() }
                              
                              // Get file data
                              let data = try Data(contentsOf: url)
                              fileData = data
                              selectedFileURL = url
                              fileName = url.lastPathComponent
                              
                              // Prepare the message text with the filename
                              messageText = fileName
                              
                          } catch {
                              print("Error reading file: \(error)")
                              chatViewModel.errorMessage = "Failed to read file: \(error.localizedDescription)"
                          }
                          
                      case .failure(let error):
                          print("File selection error: \(error)")
                          chatViewModel.errorMessage = "Failed to select file: \(error.localizedDescription)"
                      }
                  }
                  
              
    private func uploadFileWithSignalR(data: Data, fileName: String) {
            let currentChatId = self.chat.id
            isUploadingFile = true

            // Temporary placeholder — shown while uploading
            let tempMessageId = -Int.random(in: 1000000...9999999)
            let tempMessage = Message(
                id: tempMessageId,
                            displayText: "SCANNING:\(fileName)",
                name: chatViewModel.getCurrentUsername(),
                timestamp: ISO8601DateFormatter().string(from: Date()),
                isRead: false
            )
            addTemporaryMessage(tempMessage, chatId: currentChatId)

            guard let signalR = chatViewModel.signalRService as? SignalRService else {
                handleUploadError(tempMessageId: tempMessageId, chatId: currentChatId,
                                  error: NSError(domain: "SignalR", code: -1,
                                                userInfo: [NSLocalizedDescriptionKey: "SignalR not available"]))
                return
            }

            print("🔍 Starting file upload and scan")

            let capturedChatId      = currentChatId
            let capturedTempMessageId = tempMessageId

            guard let token = UserDefaults.standard.string(forKey: "authToken") else {
                handleUploadError(tempMessageId: tempMessageId, chatId: currentChatId,
                                  error: NSError(domain: "Auth", code: 401,
                                                userInfo: [NSLocalizedDescriptionKey: "No authentication token"]))
                return
            }

            let baseUrl   = "http://158.220.90.131:8444"
            let uploadUrl = "\(baseUrl)/api/Chat/upload"
            print("📤 Uploading to: \(uploadUrl)")

            var request = URLRequest(url: URL(string: uploadUrl)!)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let boundary = UUID().uuidString
            request.setValue("multipart/form-data; boundary=\(boundary)",
                             forHTTPHeaderField: "Content-Type")

            var body = Data()
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
            let mimeType = getMimeType(for: fileName)
            body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
            body.append(data)
            body.append("\r\n".data(using: .utf8)!)
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
            request.httpBody = body

            // Show UPLOADING status while the HTTP request is in flight
            updateTemporaryMessageToUploading(capturedTempMessageId,
                                              chatId: capturedChatId,
                                              fileName: fileName)

            URLSession.shared.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {

                    // ── Network error ────────────────────────────────────────────
                    if let error = error {
                        print("❌ HTTP upload failed: \(error)")
                        self.handleUploadError(tempMessageId: capturedTempMessageId,
                                              chatId: capturedChatId,
                                              error: error)
                        return
                    }

                    guard let httpResponse = response as? HTTPURLResponse else {
                        self.handleUploadError(tempMessageId: capturedTempMessageId,
                                              chatId: capturedChatId,
                                              error: NSError(domain: "Upload", code: 500,
                                                             userInfo: [NSLocalizedDescriptionKey: "No response from server"]))
                        return
                    }

                    print("📊 HTTP Status: \(httpResponse.statusCode)")

                    guard let responseData = data else {
                        self.handleUploadError(tempMessageId: capturedTempMessageId,
                                              chatId: capturedChatId,
                                              error: NSError(domain: "Upload", code: 500,
                                                             userInfo: [NSLocalizedDescriptionKey: "Empty response"]))
                        return
                    }

                    guard httpResponse.statusCode == 200 else {
                        let msg = String(data: responseData, encoding: .utf8) ?? "No response"
                        print("❌ Server error \(httpResponse.statusCode): \(msg)")
                        self.handleUploadError(tempMessageId: capturedTempMessageId,
                                              chatId: capturedChatId,
                                              error: NSError(domain: "Upload", code: httpResponse.statusCode,
                                                             userInfo: [NSLocalizedDescriptionKey: "Server error: \(httpResponse.statusCode)"]))
                        return
                    }

                    // ── Parse JSON ───────────────────────────────────────────────
                    do {
                        guard let json = try JSONSerialization.jsonObject(with: responseData,
                                                                          options: []) as? [String: Any] else {
                            throw NSError(domain: "Upload", code: 500,
                                          userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response"])
                        }

                        print("📦 Upload response JSON: \(json)")

                        // Server-side block check (some backends return isSafe in upload response)
                        let serverSaysBlocked = (json["isSafe"] as? Bool) == false
                        if serverSaysBlocked {
                            print("🚫 FILE BLOCKED DURING UPLOAD: \(fileName)")
                            self.isUploadingFile = false
                           // self.removeTemporaryMessage(capturedTempMessageId, chatId: capturedChatId)

                            if let index = self.chatViewModel.chats.firstIndex(where: { $0.id == capturedChatId }) {
                                var updatedChat = self.chatViewModel.chats[index]
                                var messages = updatedChat.messages
                                messages.removeAll { $0.id == capturedTempMessageId }
                                updatedChat = Chat(id: updatedChat.id, name: updatedChat.name,
                                                  pictureUrl: updatedChat.pictureUrl, type: updatedChat.type,
                                                  messages: messages, users: updatedChat.users,
                                                  unreadCount: updatedChat.unreadCount, isOnline: updatedChat.isOnline)
                                self.chatViewModel.chats[index] = updatedChat
                                if self.chatViewModel.currentChat?.id == capturedChatId {
                                    self.chatViewModel.currentChat = updatedChat
                                }
                                self.chatViewModel.saveChats()
                                self.chatViewModel.notifyChatsUpdated()
                            }

                            let alertMsg = "⚠️ File Blocked\n\nThe file \"\(fileName)\" contains malware and cannot be sent."
                            let alert = UIAlertController(title: "File Blocked", message: alertMsg, preferredStyle: .alert)
                            alert.addAction(UIAlertAction(title: "OK", style: .default))
                            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let root = scene.windows.first?.rootViewController {
                                root.present(alert, animated: true)
                            }
                            return
                        }

                        // ── Extract URL ──────────────────────────────────────────
                        guard let fileUrl = json["url"] as? String else {
                            print("⚠️ No 'url' field in response")
                            self.handleUploadError(
                                tempMessageId: capturedTempMessageId,
                                chatId: capturedChatId,
                                error: NSError(domain: "Upload", code: 500,
                                               userInfo: [NSLocalizedDescriptionKey: "No URL in server response"]))
                            return
                        }

                        let fullFileUrl   = fileUrl.hasPrefix("http") ? fileUrl : "\(baseUrl)\(fileUrl)"
                        let fileExtension = (fileName as NSString).pathExtension.lowercased()
                        let fileSize      = Int64(responseData.count)

                        print("✅ File uploaded successfully: \(fullFileUrl)")

                        let audioExtensions = ["m4a", "mp3", "wav", "aac", "ogg", "caf", "aiff"]
                        let isVoice = audioExtensions.contains(fileExtension)

                        if isVoice {
                            // ── VOICE: show bubble instantly, skip scanning ───────
                            // Replace the SCANNING/UPLOADING placeholder with a real
                            // optimistic voice bubble (uses the actual .m4a URL so
                            // UniversalMessageBubble renders it as VoiceMessageBubble).
                            // We keep the negative tempMessageId so that when the
                            // SignalR echo arrives, replaceOptimisticMessageImmediately
                            // finds it by URL and swaps it for the confirmed message.
                            self.isUploadingFile = false

                            if let index = self.chatViewModel.chats.firstIndex(where: { $0.id == capturedChatId }) {
                                var updatedChat = self.chatViewModel.chats[index]
                                var messages    = updatedChat.messages

                                if let tempIndex = messages.firstIndex(where: { $0.id == capturedTempMessageId }) {
                                    // Swap placeholder text for the real URL
                                    messages[tempIndex] = Message(
                                        id: capturedTempMessageId,   // still negative → optimistic
                                                    displayText: fullFileUrl,           // .m4a URL → renders as voice bubble
                                        name: self.chatViewModel.getCurrentUsername(),
                                        timestamp: ISO8601DateFormatter().string(from: Date()),
                                        isRead: true
                                    )
                                }

                                updatedChat = Chat(
                                    id: updatedChat.id, name: updatedChat.name,
                                    pictureUrl: updatedChat.pictureUrl, type: updatedChat.type,
                                    messages: messages, users: updatedChat.users,
                                    unreadCount: 0, isOnline: updatedChat.isOnline
                                )
                                self.chatViewModel.chats[index] = updatedChat

                                if self.chatViewModel.currentChat?.id == capturedChatId {
                                    self.chatViewModel.currentChat = updatedChat
                                }
                                self.chatViewModel.saveChats()
                                self.chatViewModel.notifyChatsUpdated()
                            }

                            // Track so the SignalR echo can find & replace this bubble
                            self.chatViewModel.optimisticMessageTracking[capturedTempMessageId] = fullFileUrl

                            print("🎙️ Voice message — skipping scan, sending directly")
                            signalR.sendMessage(
                                fullFileUrl,
                                chatId: capturedChatId,
                                fileUrl: fullFileUrl,
                                fileName: fileName,
                                fileSize: fileSize,
                                fileExtension: fileExtension,
                                type: .voice          // rawValue 2 — server will NOT scan
                            )
                            // ────────────────────────────────────────────────────

                        } else {
                            // ── ALL OTHER FILES: scanning flow as before ─────────
                            print("📁 Non-voice file — proceeding with scan")
                            self.updateTemporaryMessageToScanning(
                                capturedTempMessageId,
                                chatId: capturedChatId,
                                fileName: fileName
                            )

                            signalR.sendMessage(
                                fullFileUrl,
                                chatId: capturedChatId,
                                fileUrl: fullFileUrl,
                                fileName: fileName,
                                fileSize: fileSize,
                                fileExtension: fileExtension,
                                type: .file
                            )
                            // ────────────────────────────────────────────────────
                        }

                    } catch {
                        print("❌ JSON parse error: \(error)")
                        self.handleUploadError(tempMessageId: capturedTempMessageId,
                                              chatId: capturedChatId,
                                              error: error)
                    }
                }
            }.resume()
        }
    // ✅ Helper: Update message to "Uploading..." status
    private func updateTemporaryMessageToUploading(_ tempMessageId: Int, chatId: Int, fileName: String) {
        if let index = chatViewModel.chats.firstIndex(where: { $0.id == chatId }) {
            var updatedChat = chatViewModel.chats[index]
            var messages = updatedChat.messages
            
            if let tempIndex = messages.firstIndex(where: { $0.id == tempMessageId }) {
                messages[tempIndex] = Message(
                    id: tempMessageId,
                                displayText: "UPLOADING:\(fileName)", // Special prefix for uploading
                    name: chatViewModel.getCurrentUsername(),
                    timestamp: ISO8601DateFormatter().string(from: Date()),
                    isRead: false
                )
                
                updatedChat = Chat(
                    id: updatedChat.id,
                    name: updatedChat.name,
                    pictureUrl: updatedChat.pictureUrl,
                    type: updatedChat.type,
                    messages: messages,
                    users: updatedChat.users,
                    unreadCount: updatedChat.unreadCount,
                    isOnline: updatedChat.isOnline
                )
                chatViewModel.chats[index] = updatedChat
                
                if chatViewModel.currentChat?.id == chatId {
                    chatViewModel.currentChat = updatedChat
                }
                
                chatViewModel.saveChats()
            }
        }
    }

    // ✅ Helper: Update message to "Scanning..." status
    private func updateTemporaryMessageToScanning(_ tempMessageId: Int, chatId: Int, fileName: String) {
        if let index = chatViewModel.chats.firstIndex(where: { $0.id == chatId }) {
            var updatedChat = chatViewModel.chats[index]
            var messages = updatedChat.messages
            
            if let tempIndex = messages.firstIndex(where: { $0.id == tempMessageId }) {
                messages[tempIndex] = Message(
                    id: tempMessageId,
                                displayText: "SCANNING:\(fileName)", // Special prefix for scanning
                    name: chatViewModel.getCurrentUsername(),
                    timestamp: ISO8601DateFormatter().string(from: Date()),
                    isRead: false
                )
                
                updatedChat = Chat(
                    id: updatedChat.id,
                    name: updatedChat.name,
                    pictureUrl: updatedChat.pictureUrl,
                    type: updatedChat.type,
                    messages: messages,
                    users: updatedChat.users,
                    unreadCount: updatedChat.unreadCount,
                    isOnline: updatedChat.isOnline
                )
                chatViewModel.chats[index] = updatedChat
                
                if chatViewModel.currentChat?.id == chatId {
                    chatViewModel.currentChat = updatedChat
                }
                
                chatViewModel.saveChats()
            }
        }
    }

    private func getMimeType(for fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        
        switch ext {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "pdf": return "application/pdf"
        case "doc": return "application/msword"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "txt": return "text/plain"
        case "rtf": return "application/rtf"
        case "zip": return "application/zip"
        case "rar": return "application/x-rar-compressed"
        case "m4a": return "audio/mp4"
        case "mp3": return "audio/mpeg"
        case "aac": return "audio/aac"
        case "wav": return "audio/wav"
        default: return "application/octet-stream"
        }
    }
    // ✅ Helper: Handle upload errors
    private func handleUploadError(tempMessageId: Int, chatId: Int, error: Error) {
        DispatchQueue.main.async {
            self.isUploadingFile = false
            
            // Update temp message to show error
            self.updateTemporaryMessageWithError(tempMessageId, chatId: chatId, error: error)
            
            // Show error to user
            self.chatViewModel.errorMessage = "Upload failed: \(error.localizedDescription)"
            
            // Clear file selection
            self.clearFileSelection()
        }
    }
    // ✅ Helper: Add temporary message
    private func addTemporaryMessage(_ message: Message, chatId: Int) {
        if let index = chatViewModel.chats.firstIndex(where: { $0.id == chatId }) {
            var updatedChat = chatViewModel.chats[index]
            var updatedMessages = updatedChat.messages
            updatedMessages.append(message)
            
            updatedChat = Chat(
                id: updatedChat.id,
                name: updatedChat.name,
                pictureUrl: updatedChat.pictureUrl,
                type: updatedChat.type,
                messages: updatedMessages,
                users: updatedChat.users,
                unreadCount: updatedChat.unreadCount,
                isOnline: updatedChat.isOnline
            )
            chatViewModel.chats[index] = updatedChat
            
            if chatViewModel.currentChat?.id == chatId {
                chatViewModel.currentChat = updatedChat
            }
            
            chatViewModel.saveChats()
        }
    }

    // ✅ Helper: Update message with error
    private func updateTemporaryMessageWithError(_ tempMessageId: Int, chatId: Int, error: Error) {
        if let index = chatViewModel.chats.firstIndex(where: { $0.id == chatId }) {
            var updatedChat = chatViewModel.chats[index]
            var messages = updatedChat.messages
            
            if let tempIndex = messages.firstIndex(where: { $0.id == tempMessageId }) {
                messages[tempIndex] = Message(
                    id: tempMessageId,
                                displayText: "❌ Upload failed: \(error.localizedDescription)\nTap to retry",
                    name: chatViewModel.getCurrentUsername(),
                    timestamp: ISO8601DateFormatter().string(from: Date()),
                    isRead: false
                )
                
                updatedChat = Chat(
                    id: updatedChat.id,
                    name: updatedChat.name,
                    pictureUrl: updatedChat.pictureUrl,
                    type: updatedChat.type,
                    messages: messages,
                    users: updatedChat.users,
                    unreadCount: updatedChat.unreadCount,
                    isOnline: updatedChat.isOnline
                )
                chatViewModel.chats[index] = updatedChat
                
                if chatViewModel.currentChat?.id == chatId {
                    chatViewModel.currentChat = updatedChat
                }
                
                chatViewModel.saveChats()
            }
        }
    }

//    // ✅ Helper: Remove temporary message
//    private func removeTemporaryMessage(_ tempMessageId: Int, chatId: Int) {
//        if let index = chatViewModel.chats.firstIndex(where: { $0.id == chatId }) {
//            var updatedChat = chatViewModel.chats[index]
//            var messages = updatedChat.messages
//            messages.removeAll { $0.id == tempMessageId }
//            
//            updatedChat = Chat(
//                id: updatedChat.id,
//                name: updatedChat.name,
//                pictureUrl: updatedChat.pictureUrl,
//                type: updatedChat.type,
//                messages: messages,
//                users: updatedChat.users,
//                unreadCount: updatedChat.unreadCount,
//                isOnline: updatedChat.isOnline
//            )
//            chatViewModel.chats[index] = updatedChat
//            
//            if chatViewModel.currentChat?.id == chatId {
//                chatViewModel.currentChat = updatedChat
//            }
//            
//            chatViewModel.saveChats()
//        }
//    }

    // ✅ Helper: Clear file selection
    private func clearFileSelection() {
        selectedFileURL = nil
        fileData = nil
        fileName = ""
        messageText = ""
    }

    // ✅ Update your sendFileMessage method
    private func sendFileMessage(data: Data, fileName: String) {
        let fileExtension = (fileName as NSString).pathExtension.lowercased()
        
        // Define which extensions are actual images
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "webp", "bmp", "tiff"]
        let isImage = imageExtensions.contains(fileExtension)
        
        if isImage {
            // Check if the data is actually a valid image
            if let image = UIImage(data: data) {
                chatViewModel.sendImageMessage(image, chatId: chat.id)
                clearFileSelection()
            } else {
                // If it's not a valid image, treat it as a regular file
                uploadFileWithSignalR(data: data, fileName: fileName)
            }
        } else {
            // Use SignalR for all other files
            uploadFileWithSignalR(data: data, fileName: fileName)
        }
    }

    // ✅ IMPORTANT: Monitor FileStatusUpdated events
    // Add this to your view's onAppear or init
    private func setupFileUploadMonitoring() {
        // The ChatViewModel already handles FileStatusUpdated events
        // When a file upload completes, the server sends:
        // FileStatusUpdated(messageId, fileUrl, isSafe, fileName)
        
        // Your ChatViewModel.handleFileStatusUpdate() will:
        // 1. Find the temporary message by matching text/sender
        // 2. Replace it with the real message containing the file URL
        // 3. Show if file is blocked or safe
        
        print("📡 Monitoring for FileStatusUpdated events...")
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
        
        // Since messages are now in ascending order, the last message is the newest
        let targetId: String? = typingUser != nil ? "typing-indicator" : (messages.last.map { String(describing: $0.id) })
        
        if let targetId = targetId {
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.3)) {
                    scrollProxy?.scrollTo(targetId, anchor: .bottom)
                }
            }
        }
    }
    private func uploadVoiceNote(data: Data, fileName: String) {
        // Reuse your existing upload flow — just with the .m4a file
        uploadFileWithSignalR(data: data, fileName: fileName)
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
    
    private var statusText: String {
        switch checkmarkState {
        case .sent: return "Sent"
        case .delivered: return "Delivered"
        case .seen: return "Seen"
        }
    }
    // ✅ ADD THIS: MessageType enum
    // Update the MessageType enum
    private enum MessageType {
        case text
        case image(url: String, isBlocked: Bool)
        case file(url: String, name: String, isBlocked: Bool)
        case scanning(fileName: String) // ADD THIS
        case voice(url: String)
    }

     
    @State private var showStatusTooltip = false
    private var isFileBlocked: Bool {
           if let fileData = chatViewModel.fileStatusUpdates[message.id] {
               return !fileData.isSafe
           }
           return false
       }
       

    private var messageType: MessageType {
        
        // Add to your audio extensions list
        let audioExtensions = [".m4a", ".mp3", ".mp4", ".aac", ".wav", ".ogg"]
        let text = message.displayText.trimmingCharacters(in: .whitespaces)
        if audioExtensions.contains(where: { text.lowercased().hasSuffix($0) }) ||
           text.contains("/uploads/voice/") {
            let fullUrl = buildFullUrl(text)
            return .voice(url: fullUrl)
        }
        // Check for scanning messages first (using the new prefix)
        if text.hasPrefix("SCANNING:") {
            let fileName = text.replacingOccurrences(of: "SCANNING:", with: "")
            return .scanning(fileName: fileName)
        }
        
        // Check for uploading messages
        if text.hasPrefix("UPLOADING:") {
            let fileName = text.replacingOccurrences(of: "UPLOADING:", with: "")
            return .scanning(fileName: fileName) // Use same scanning view for uploading
        }
        
        
        // Check if it's a regular web link FIRST (NOT a file)
        if isRegularWebLink(text) {
            print("🔗 Detected as REGULAR LINK: \(text)")
            return .text  // Display as clickable text, not as file
        }
        
        
        // Check for scanning messages first
           if message.displayText.hasPrefix("SCANNING:") || message.displayText.hasPrefix("UPLOADING:") {
               let fileName = message.displayText.replacingOccurrences(of: "SCANNING:", with: "")
                   .replacingOccurrences(of: "UPLOADING:", with: "")
               return .scanning(fileName: fileName)
           }
           
           // Use the typed field from backend
           let url = message.fileUrl ?? message.displayText
           
           switch message.type {
           case .voice:
               return .voice(url: buildFullUrl(url))
               
               case .image:
                   let blocked = message.isSafe == false && message.id > 0
                                 && !message.displayText.hasPrefix("SCANNING:")
                   return .image(url: buildFullUrl(url), isBlocked: blocked)

           case .file:
               let name = message.fileName ?? URL(string: buildFullUrl(url))?.lastPathComponent ?? url
               return .file(url: buildFullUrl(url), name: name, isBlocked: message.isSafe == false)
               
           case .video:
               // Handle video if needed
               return .file(url: buildFullUrl(url), name: message.fileName ?? url, isBlocked: false)
               
           default:
               // Check if it's a regular web link
               if isRegularWebLink(message.displayText) {
                   return .text
               }
               
               // Check if it's an uploaded file (backward compatibility)
               if isUploadedFile(message.displayText) {
                   let fullUrl = buildFullUrl(message.displayText)
                   let isBlocked = message.isSafe == false
                   
                   if isImageFile(message.displayText) {
                       return .image(url: fullUrl, isBlocked: isBlocked)
                   } else {
                       let name = URL(string: fullUrl)?.lastPathComponent ?? message.displayText
                       return .file(url: fullUrl, name: name, isBlocked: isBlocked)
                   }
               }
               
               return .text
           }
       }

    // Add helper methods
    private func isImageFile(_ text: String) -> Bool {
        let imageExtensions = [".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp", ".tiff"]
        return imageExtensions.contains { text.lowercased().hasSuffix($0) }
    }


    private func buildFullUrl(_ text: String) -> String {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleaned.hasPrefix("http://") || cleaned.hasPrefix("https://") {
            return cleaned
        }
        
        let baseUrl = "http://158.220.90.131:8444"
        
        if cleaned.hasPrefix("/uploads") {
            return "\(baseUrl)\(cleaned)"
        }
        
        return "\(baseUrl)/uploads/\(cleaned)"
    }
       
    
    var body: some View {
           HStack(alignment: .bottom, spacing: 8) {
               if !isCurrentUser {
                   Spacer(minLength: 50)
               }
               
               messageContent
               
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
    private func containsURL(_ text: String) -> Bool {
        let detector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        return !matches.isEmpty
    }
    // MARK: - Helper Functions for Link Detection

    // In UniversalMessageBubble — isUploadedFile()
    private func isUploadedFile(_ text: String) -> Bool {
        let fileExtensions = [".pdf", ".doc", ".docx", ".txt", ".rtf", ".zip", ".rar",
                              ".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp", ".tiff",
                              ".m4a", ".mp3", ".aac", ".wav"] // ADD AUDIO TYPES
        return fileExtensions.contains { text.lowercased().hasSuffix($0) }
    }

    private func isRegularWebLink(_ text: String) -> Bool {
        // It's a regular web link if:
        // 1. It starts with http:// or https://
        // 2. AND it's NOT an uploaded file from our server
        
        guard text.hasPrefix("http://") || text.hasPrefix("https://") else {
            return false
        }
        
        // If it has a file extension, it's a file
        if isUploadedFile(text) {
            return false
        }
        
        // Otherwise, it's a regular web link
        return true
    }
    @ViewBuilder
    private var messageContent: some View {
        VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
            switch messageType {
            case .voice(let url):
                VoiceMessageBubble(
                    audioURL: url,
                    isCurrentUser: isCurrentUser,
                    duration: nil
                )
            case .text:
                if message.displayText.hasPrefix("http://") || message.displayText.hasPrefix("https://") {
                    // ✅ URL bubble with timestamp inside
                    ZStack(alignment: .bottomTrailing) {
                        ClickableLinkText(
                            text: message.displayText,
                            bubbleBackground: bubbleBackground,
                            bubbleForeground: bubbleForeground
                        )
                        .contextMenu {
                            Button(action: { UIPasteboard.general.string = message.displayText }) {
                                Label("Copy Link", systemImage: "doc.on.doc")
                            }
                            if let url = URL(string: message.displayText) {
                                Button(action: { UIApplication.shared.open(url) }) {
                                    Label("Open in Browser", systemImage: "safari")
                                }
                            }
                        }

                        timestampView
                            .padding(.trailing, 8)
                            .padding(.bottom, 6)
                    }
                } else {
                    // ✅ Text bubble with timestamp inside
                    ZStack(alignment: .bottomTrailing) {
                        Text(message.displayText + "          ")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(bubbleBackground)
                            .foregroundColor(bubbleForeground)
                            .cornerRadius(12)
                            .fixedSize(horizontal: false, vertical: true)
                            .contextMenu {
                                Button(action: { UIPasteboard.general.string = message.displayText }) {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                            }

                        timestampView
                            .padding(.trailing, 8)
                            .padding(.bottom, 6)
                    }
                }

            case .image(let url, let isBlocked):
                // ✅ Image with timestamp overlaid on bottom-right
                ZStack(alignment: .bottomTrailing) {
                    ImageMessageView(
                        imageUrl: url,
                        isCurrentUser: isCurrentUser,
                        isBlocked: isBlocked
                    )

                    timestampView
                        .padding(.trailing, 8)
                        .padding(.bottom, 8)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.35))
                                .padding(.horizontal, -6)
                                .padding(.vertical, -3)
                        )
                }

            case .file(let url, let name, let isBlocked):
                // ✅ File bubble with timestamp inside bottom-right
                ZStack(alignment: .bottomTrailing) {
                    FileMessageView(
                        fileUrl: url,
                        fileName: name,
                        isCurrentUser: isCurrentUser,
                        bubbleForeground: bubbleForeground,
                        isBlocked: isBlocked
                    )

                    timestampView
                        .padding(.trailing, 8)
                        .padding(.bottom, 8)
                }

            case .scanning(let fileName):
                // ✅ Scanning bubble with timestamp inside
                ZStack(alignment: .bottomTrailing) {
                    ScanningMessageView(
                        fileName: fileName,
                        isCurrentUser: isCurrentUser
                    )

                    timestampView
                        .padding(.trailing, 8)
                        .padding(.bottom, 8)
                }
            }
        }
    }

    // ✅ Reusable timestamp + checkmark view
    @ViewBuilder
    private var timestampView: some View {
        HStack(spacing: 3) {
            Text(message.formattedTime)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isCurrentUser ? .white.opacity(0.7) : .gray)

            if isCurrentUser {
                checkmarkView
            }
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
    
    @ViewBuilder
    private var seenIndicatorButton: some View {
        Button(action: {
            showStatusTooltip.toggle()
        }) {
            seenIndicatorView
        }
        .buttonStyle(.plain)
        .overlay(
            Group {
                if showStatusTooltip {
                    statusTooltipView
                }
            },
            alignment: .bottom
        )
    }
    
    @ViewBuilder
    private var seenIndicatorView: some View {
        HStack(spacing: 4) {
            Text(message.formattedTime)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.gray)

            if isCurrentUser {
                checkmarkView
            }
        }
        .padding(.horizontal, 4)
    }
    
    @ViewBuilder
    private var checkmarkView: some View {
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
    @ViewBuilder
    private var statusTooltipView: some View {
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
}
struct ImageMessageView: View {
    let imageUrl: String
        let isCurrentUser: Bool
        let isBlocked: Bool
        
        @State private var showFullScreen = false
        @State private var imageLoadError: Error?
        @State private var isLoading = false
        
        private var cleanedImageUrl: String {
            // Clean and encode the URL
            let cleaned = imageUrl.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // If it's already a full URL, return it encoded
            if cleaned.hasPrefix("http://") || cleaned.hasPrefix("https://") {
                if let encoded = cleaned.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                    print("🖼️ Encoded full URL: \(encoded)")
                    return encoded
                }
            }
            
            // Handle file paths from server
            let baseUrl = "http://158.220.90.131:8444"
            
            // If it starts with /uploads (from FileStatusUpdated event)
            if cleaned.hasPrefix("/uploads") {
                let fullUrl = "\(baseUrl)\(cleaned)"
                if let encoded = fullUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                    print("🖼️ Built URL from /uploads path: \(encoded)")
                    return encoded
                }
                return fullUrl
            }
            
            // If it's just a filename (like image.jpg)
            let fullUrl = "\(baseUrl)/uploads/\(cleaned)"
            if let encoded = fullUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                print("🖼️ Built URL from filename: \(encoded)")
                return encoded
            }
            
            print("⚠️ Could not build proper URL for: \(cleaned)")
            return cleaned
        }
    
    var body: some View {
        if isBlocked {
            blockedContentView
        } else {
            normalContentView
        }
    }
    private var blockedContentView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                
                Text("Image Blocked")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.red)
            }
            
            Text("This image was blocked for security reasons")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
        }
        .padding(12)
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
    }
    private var normalContentView: some View {
           VStack(alignment: .leading, spacing: 8) {
               AsyncImage(url: URL(string: cleanedImageUrl)) { phase in
                   switch phase {
                   case .empty:
                       ProgressView()
                           .frame(width: 200, height: 200)
                           .background(Color.gray.opacity(0.1))
                           .cornerRadius(12)
                           .onAppear {
                               print("🖼️ Loading image from: \(cleanedImageUrl)")
                               print("   Original URL: \(imageUrl)")
                               isLoading = true
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
                               print("✅ Image loaded successfully: \(cleanedImageUrl)")
                               isLoading = false
                               imageLoadError = nil
                           }
                       
                   case .failure(let error):
                       errorContentView(error: error)
                       
                   @unknown default:
                       EmptyView()
                   }
               }
           }
           .contextMenu {
               Button(action: {
                   UIPasteboard.general.string = cleanedImageUrl
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
               FullScreenImageView(imageUrl: cleanedImageUrl)
           }
       }
       
    
    private func errorContentView(error: Error) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 30))
                .foregroundColor(.orange)
            
            Text("Failed to load image")
                .font(.caption)
                .foregroundColor(.gray)
            
            Button("Retry") {
                // The AsyncImage will retry automatically when state changes
                // We can force a refresh by changing the URL slightly
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
        .frame(width: 200, height: 200)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .onAppear {
            print("❌ Image failed to load: \(cleanedImageUrl)")
            print("   Error: \(error)")
            isLoading = false
            imageLoadError = error
        }
    }
    
    private func downloadImage() {
        guard let url = URL(string: cleanedImageUrl) else {
            print("❌ Invalid URL for download")
            return
        }
        
        print("⬇️ Downloading image from: \(url.absoluteString)")
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ Download error: \(error)")
                return
            }
            
            guard let data = data, let image = UIImage(data: data) else {
                print("❌ Invalid image data")
                return
            }
            
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            print("✅ Image saved to photos album")
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

struct FileMessageView: View {
    let fileUrl: String
    let fileName: String
    let isCurrentUser: Bool
    let bubbleForeground: Color
    let isBlocked: Bool
    
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
        if isBlocked {
            blockedContentView
        } else {
            normalContentView
        }
    }
    
    private var blockedContentView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 20))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("File Blocked")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.red)
                    
                    Text(fileName)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Text("This file was blocked for security reasons")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var normalContentView: some View {
        HStack(spacing: 12) {
            // Download button on the left
            Button(action: openFile) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(isCurrentUser ? .white : .blue)
            }
            .buttonStyle(PlainButtonStyle())
            
            //                // File icon in the middle
            //                Image(systemName: fileIcon)
            //                    .font(.system(size: 32))
            //                    .foregroundColor(isCurrentUser ? .white : .blue)
                            
            // File info
            VStack(alignment: .leading, spacing: 4) {
                Text(fileName)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(2)
                
                Text(fileExtension)
                    .font(.system(size: 12))
                    .opacity(0.7)
            }
        }
        .padding(12)
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
// MARK: - Updated ChatDetailView for File Scanning

extension ChatDetailView {
    private func sendMessageWithFileCheck() {
        let trimmedMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return }
        
        // Check if this is a file/image message
        let isFile = trimmedMessage.lowercased().hasSuffix(".jpg") ||
                    trimmedMessage.lowercased().hasSuffix(".jpeg") ||
                    trimmedMessage.lowercased().hasSuffix(".png") ||
                    trimmedMessage.lowercased().hasSuffix(".gif") ||
                    trimmedMessage.lowercased().hasSuffix(".webp") ||
                    trimmedMessage.lowercased().hasSuffix(".pdf") ||
                    trimmedMessage.lowercased().hasSuffix(".doc") ||
                    trimmedMessage.lowercased().hasSuffix(".docx") ||
                    trimmedMessage.lowercased().hasSuffix(".txt") ||
                    trimmedMessage.lowercased().hasSuffix(".zip")
        
        if isFile {
            // Use file scanning for files
            chatViewModel.sendMessageWithScan(trimmedMessage, chatId: chat.id, isFile: true)
        } else {
            // Regular text message
            chatViewModel.sendMessage(trimmedMessage, chatId: chat.id)
        }
        
        messageText = ""
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            scrollToBottom()
        }
    }
}
// Also update the SignalRService to handle file-specific methods
extension SignalRService {
    
    /// Send file via SignalR
    func sendFile(_ data: Data, fileName: String, chatId: Int) -> AnyPublisher<Bool, Error> {
        return Future<Bool, Error> { [weak self] promise in
            guard let self = self, self.connectionState == .connected else {
                promise(.failure(NSError(domain: "SignalR", code: -1,
                                         userInfo: [NSLocalizedDescriptionKey: "SignalR not connected"])))
                return
            }
            
            // Convert to base64
            let base64String = data.base64EncodedString()
            
            // Try different method names
            let methodsToTry = ["SendFile", "UploadFile", "ReceiveFile", "SendPrivateMessage"]
            
            func tryMethod(index: Int) {
                guard index < methodsToTry.count else {
                    promise(.failure(NSError(domain: "SignalR", code: -2,
                                             userInfo: [NSLocalizedDescriptionKey: "No file method worked"])))
                    return
                }
                
                let method = methodsToTry[index]
                print("🔄 Trying method: \(method)")
                
                if method == "SendPrivateMessage" {
                    // For SendPrivateMessage, we need to send as a message
                    let message = "FILE_UPLOAD:\(fileName):\(base64String.prefix(100))..."
                    self.connection.invoke(method: method, message, chatId, fileName) { error in
                        if let error = error {
                            print("❌ \(method) failed: \(error)")
                            tryMethod(index: index + 1)
                        } else {
                            print("✅ File sent via \(method)")
                            promise(.success(true))
                        }
                    }
                } else {
                    // For file-specific methods
                    self.connection.invoke(method: method, base64String, fileName, chatId) { error in
                        if let error = error {
                            print("❌ \(method) failed: \(error)")
                            tryMethod(index: index + 1)
                        } else {
                            print("✅ File sent via \(method)")
                            promise(.success(true))
                        }
                    }
                }
            }
            
            tryMethod(index: 0)
        }
        .eraseToAnyPublisher()
    }
    
}


struct VoiceRecordButton: View {
    @Binding var isRecording: Bool
    let recorder: VoiceRecorderService
    let onStop: (URL?) -> Void

    var body: some View {
        Button {
            if isRecording {
                let url = recorder.stopRecording()
                isRecording = false
                onStop(url)
            } else {
                recorder.requestPermission { granted in
                    guard granted else { return }
                    do {
                        try recorder.startRecording()
                        isRecording = true
                    } catch {
                        print("❌ Failed to start recording: \(error)")
                    }
                }
            }
        } label: {
            Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                .font(.title2)
                .foregroundStyle(
                    isRecording
                        ? LinearGradient(colors: [.red], startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                )
                .scaleEffect(isRecording ? 1.15 : 1.0)
                .animation(
                    isRecording
                        ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
                        : .default,
                    value: isRecording
                )
        }
    }
}
