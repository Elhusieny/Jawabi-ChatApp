////
////  FileUploadManager.swift
////  Chat
////
////  Created by Ahmed Elhussieny on 02/06/2026.
////
//
//
//import SwiftUI
//import Combine
//
//
//
//// MARK: - FileUploadManager
///// Handles HTTP multipart upload + SignalR dispatch for files and voice messages
//class FileUploadManager {
//    
//    static let shared = FileUploadManager()
//    private let baseUrl = "http://158.220.90.131:8444"
//    
//    private init() {}
//    
//    // MARK: - Main Upload Method
//    func uploadFile(
//        data: Data,
//        fileName: String,
//        chat: Chat,
//        chatViewModel: ChatViewModel,
//        onUploadStarted: @escaping (_ tempId: Int) -> Void = { _ in },
//        onComplete: @escaping () -> Void = {}
//    ) {
//        let chatId = chat.id
//        let isGroup = chat.type == 0
//        
//        guard let token = UserDefaults.standard.string(forKey: "authToken") else {
//            print("❌ No auth token")
//            DispatchQueue.main.async {
//                chatViewModel.errorMessage = "Authentication failed. Please login again."
//            }
//            onComplete()
//            return
//        }
//        
//        guard let signalR = chatViewModel.signalRService as? SignalRService else {
//            print("❌ SignalR unavailable")
//            DispatchQueue.main.async {
//                chatViewModel.errorMessage = "Connection error. Please try again."
//            }
//            onComplete()
//            return
//        }
//        
//        // Insert temporary placeholder message
//        let tempId = -Int.random(in: 1_000_000...9_999_999)
//        let placeholder = Message(
//            id: tempId,
//            displayText: "SCANNING:\(fileName)",
//            name: chatViewModel.getCurrentUsername(),
//            timestamp: ISO8601DateFormatter().string(from: Date()),
//            isRead: false
//        )
//        
//        insertMessage(placeholder, chatId: chatId, chatViewModel: chatViewModel)
//        onUploadStarted(tempId)
//        
//        // Update to uploading status
//        updateMessageStatus(tempId, chatId: chatId, status: .uploading, fileName: fileName, chatViewModel: chatViewModel)
//        
//        // Build and send upload request
//        performUploadRequest(
//            data: data,
//            fileName: fileName,
//            token: token,
//            chatId: chatId,
//            tempId: tempId,
//            isGroup: isGroup,
//            signalR: signalR,
//            chatViewModel: chatViewModel,
//            onComplete: onComplete
//        )
//    }
//    
//    // MARK: - Private Upload Request
//    private func performUploadRequest(
//        data: Data,
//        fileName: String,
//        token: String,
//        chatId: Int,
//        tempId: Int,
//        isGroup: Bool,
//        signalR: SignalRService,
//        chatViewModel: ChatViewModel,
//        onComplete: @escaping () -> Void
//    ) {
//        let uploadUrl = URL(string: "\(baseUrl)/api/Chat/upload")!
//        var request = URLRequest(url: uploadUrl)
//        request.httpMethod = "POST"
//        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
//        
//        let boundary = UUID().uuidString
//        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
//        
//        var body = Data()
//        body.append("--\(boundary)\r\n".data(using: .utf8)!)
//        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
//        body.append("Content-Type: \(getMimeType(for: fileName))\r\n\r\n".data(using: .utf8)!)
//        body.append(data)
//        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
//        request.httpBody = body
//        
//        URLSession.shared.dataTask(with: request) { [weak self] responseData, response, error in
//            DispatchQueue.main.async {
//                guard let self = self else { return }
//                
//                if let error = error {
//                    self.handleUploadError(tempId: tempId, chatId: chatId, error: error, chatViewModel: chatViewModel)
//                    onComplete()
//                    return
//                }
//                
//                guard let httpResponse = response as? HTTPURLResponse,
//                      let responseData = responseData else {
//                    self.handleUploadError(tempId: tempId, chatId: chatId,
//                                          error: NSError(domain: "Upload", code: 500,
//                                                        userInfo: [NSLocalizedDescriptionKey: "No response from server"]),
//                                          chatViewModel: chatViewModel)
//                    onComplete()
//                    return
//                }
//                
//                guard httpResponse.statusCode == 200 else {
//                    let msg = String(data: responseData, encoding: .utf8) ?? "Server error"
//                    self.handleUploadError(tempId: tempId, chatId: chatId,
//                                          error: NSError(domain: "Upload", code: httpResponse.statusCode,
//                                                        userInfo: [NSLocalizedDescriptionKey: "Server error: \(httpResponse.statusCode) - \(msg)"]),
//                                          chatViewModel: chatViewModel)
//                    onComplete()
//                    return
//                }
//                
//                self.handleUploadResponse(
//                    data: responseData,
//                    fileName: fileName,
//                    fileData: data,
//                    chatId: chatId,
//                    tempId: tempId,
//                    isGroup: isGroup,
//                    signalR: signalR,
//                    chatViewModel: chatViewModel
//                )
//                onComplete()
//            }
//        }.resume()
//    }
//    
//    // MARK: - Handle Upload Response
//    private func handleUploadResponse(
//        data: Data,
//        fileName: String,
//        fileData: Data,
//        chatId: Int,
//        tempId: Int,
//        isGroup: Bool,
//        signalR: SignalRService,
//        chatViewModel: ChatViewModel
//    ) {
//        do {
//            guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
//                throw NSError(domain: "Upload", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response"])
//            }
//            
//            print("📦 Upload response JSON: \(json)")
//            
//            // Check if file is blocked
//            if (json["isSafe"] as? Bool) == false {
//                handleBlockedFile(tempId: tempId, chatId: chatId, fileName: fileName, chatViewModel: chatViewModel)
//                return
//            }
//            
//            guard let fileUrl = json["url"] as? String else {
//                throw NSError(domain: "Upload", code: 500, userInfo: [NSLocalizedDescriptionKey: "No URL in server response"])
//            }
//            
//            let fullFileUrl = fileUrl.hasPrefix("http") ? fileUrl : "\(baseUrl)\(fileUrl)"
//            let fileExtension = (fileName as NSString).pathExtension.lowercased()
//            let fileSize = Int64(fileData.count)
//            
//            let audioExtensions = ["m4a", "mp3", "wav", "aac", "ogg", "caf", "aiff"]
//            let isVoice = audioExtensions.contains(fileExtension)
//            
//            if isVoice {
//                // Voice message - update directly to final message
//                updateToFinalMessage(tempId: tempId, chatId: chatId, fileUrl: fullFileUrl, chatViewModel: chatViewModel)
//                chatViewModel.optimisticMessageTracking[tempId] = fullFileUrl
//            } else {
//                // Regular file - update to scanning status
//                updateMessageStatus(tempId, chatId: chatId, status: .scanning, fileName: fileName, chatViewModel: chatViewModel)
//            }
//            
//            // Send via SignalR - Use the existing MessageType enum
//            let messageType: MessageType = isVoice ? .voice : .file
//            
//            if isGroup {
//                signalR.sendGroupMessage(
//                    fullFileUrl,
//                    chatId: chatId,
//                    fileUrl: fullFileUrl,
//                    fileName: fileName,
//                    fileSize: fileSize,
//                    fileExtension: fileExtension,
//                    type: messageType
//                )
//            } else {
//                signalR.sendMessage(
//                    fullFileUrl,
//                    chatId: chatId,
//                    fileUrl: fullFileUrl,
//                    fileName: fileName,
//                    fileSize: fileSize,
//                    fileExtension: fileExtension,
//                    type: messageType
//                )
//            }
//            
//        } catch {
//            handleUploadError(tempId: tempId, chatId: chatId, error: error, chatViewModel: chatViewModel)
//        }
//    }
//    
//    // MARK: - Helper Methods
//    private enum MessageStatus {
//        case uploading
//        case scanning
//    }
//    
//    private func updateMessageStatus(_ tempId: Int, chatId: Int, status: MessageStatus, fileName: String, chatViewModel: ChatViewModel) {
//        let prefix = status == .uploading ? "UPLOADING" : "SCANNING"
//        updateMessageText(tempId, chatId: chatId, displayText: "\(prefix):\(fileName)", chatViewModel: chatViewModel)
//    }
//    
//    private func updateToFinalMessage(tempId: Int, chatId: Int, fileUrl: String, chatViewModel: ChatViewModel) {
//        updateMessageText(tempId, chatId: chatId, displayText: fileUrl, chatViewModel: chatViewModel)
//    }
//    
//    private func updateMessageText(_ tempId: Int, chatId: Int, displayText: String, chatViewModel: ChatViewModel) {
//        guard let index = chatViewModel.chats.firstIndex(where: { $0.id == chatId }) else { return }
//        
//        var updatedChat = chatViewModel.chats[index]
//        var messages = updatedChat.messages
//        
//        if let tempIndex = messages.firstIndex(where: { $0.id == tempId }) {
//            messages[tempIndex] = Message(
//                id: tempId,
//                displayText: displayText,
//                name: messages[tempIndex].name,
//                timestamp: ISO8601DateFormatter().string(from: Date()),
//                isRead: false
//            )
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
//            
//            chatViewModel.chats[index] = updatedChat
//            if chatViewModel.currentChat?.id == chatId {
//                chatViewModel.currentChat = updatedChat
//            }
//            chatViewModel.saveChats()
//            chatViewModel.notifyChatsUpdated()
//        }
//    }
//    
//    private func insertMessage(_ message: Message, chatId: Int, chatViewModel: ChatViewModel) {
//        guard let index = chatViewModel.chats.firstIndex(where: { $0.id == chatId }) else { return }
//        
//        var updatedChat = chatViewModel.chats[index]
//        var messages = updatedChat.messages
//        messages.append(message)
//        
//        updatedChat = Chat(
//            id: updatedChat.id,
//            name: updatedChat.name,
//            pictureUrl: updatedChat.pictureUrl,
//            type: updatedChat.type,
//            messages: messages,
//            users: updatedChat.users,
//            unreadCount: updatedChat.unreadCount,
//            isOnline: updatedChat.isOnline
//        )
//        
//        chatViewModel.chats[index] = updatedChat
//        if chatViewModel.currentChat?.id == chatId {
//            chatViewModel.currentChat = updatedChat
//        }
//        chatViewModel.saveChats()
//        chatViewModel.notifyChatsUpdated()
//    }
//    
//    private func removeMessage(_ tempId: Int, chatId: Int, chatViewModel: ChatViewModel) {
//        guard let index = chatViewModel.chats.firstIndex(where: { $0.id == chatId }) else { return }
//        
//        var updatedChat = chatViewModel.chats[index]
//        var messages = updatedChat.messages
//        messages.removeAll { $0.id == tempId }
//        
//        updatedChat = Chat(
//            id: updatedChat.id,
//            name: updatedChat.name,
//            pictureUrl: updatedChat.pictureUrl,
//            type: updatedChat.type,
//            messages: messages,
//            users: updatedChat.users,
//            unreadCount: updatedChat.unreadCount,
//            isOnline: updatedChat.isOnline
//        )
//        
//        chatViewModel.chats[index] = updatedChat
//        if chatViewModel.currentChat?.id == chatId {
//            chatViewModel.currentChat = updatedChat
//        }
//        chatViewModel.saveChats()
//        chatViewModel.notifyChatsUpdated()
//    }
//    
//    private func handleBlockedFile(tempId: Int, chatId: Int, fileName: String, chatViewModel: ChatViewModel) {
//        removeMessage(tempId, chatId: chatId, chatViewModel: chatViewModel)
//        
//        let alert = UIAlertController(
//            title: "File Blocked",
//            message: "⚠️ The file \"\(fileName)\" contains malware and cannot be sent.",
//            preferredStyle: .alert
//        )
//        alert.addAction(UIAlertAction(title: "OK", style: .default))
//        
//        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
//           let root = scene.windows.first?.rootViewController {
//            root.present(alert, animated: true)
//        }
//    }
//    
//    private func handleUploadError(tempId: Int, chatId: Int, error: Error, chatViewModel: ChatViewModel) {
//        updateMessageText(
//            tempId,
//            chatId: chatId,
//            displayText: "❌ Upload failed: \(error.localizedDescription)\nTap to retry",
//            chatViewModel: chatViewModel
//        )
//        chatViewModel.errorMessage = "Upload failed: \(error.localizedDescription)"
//    }
//    
//    private func getMimeType(for fileName: String) -> String {
//        let ext = (fileName as NSString).pathExtension.lowercased()
//        
//        switch ext {
//        case "jpg", "jpeg": return "image/jpeg"
//        case "png": return "image/png"
//        case "gif": return "image/gif"
//        case "webp": return "image/webp"
//        case "pdf": return "application/pdf"
//        case "doc": return "application/msword"
//        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
//        case "txt": return "text/plain"
//        case "rtf": return "application/rtf"
//        case "zip": return "application/zip"
//        case "rar": return "application/x-rar-compressed"
//        case "m4a": return "audio/mp4"
//        case "mp3": return "audio/mpeg"
//        case "aac": return "audio/aac"
//        case "wav": return "audio/wav"
//        default: return "application/octet-stream"
//        }
//    }
//}
//// Also update the SignalRService to handle file-specific methods
//extension SignalRService {
//    
//    /// Send file via SignalR
//    func sendFile(_ data: Data, fileName: String, chatId: Int) -> AnyPublisher<Bool, Error> {
//        return Future<Bool, Error> { [weak self] promise in
//            guard let self = self, self.connectionState == .connected else {
//                promise(.failure(NSError(domain: "SignalR", code: -1,
//                                         userInfo: [NSLocalizedDescriptionKey: "SignalR not connected"])))
//                return
//            }
//            
//            // Convert to base64
//            let base64String = data.base64EncodedString()
//            
//            // Try different method names
//            let methodsToTry = ["SendFile", "UploadFile", "ReceiveFile", "SendPrivateMessage"]
//            
//            func tryMethod(index: Int) {
//                guard index < methodsToTry.count else {
//                    promise(.failure(NSError(domain: "SignalR", code: -2,
//                                             userInfo: [NSLocalizedDescriptionKey: "No file method worked"])))
//                    return
//                }
//                
//                let method = methodsToTry[index]
//                print("🔄 Trying method: \(method)")
//                
//                if method == "SendPrivateMessage" {
//                    // For SendPrivateMessage, we need to send as a message
//                    let message = "FILE_UPLOAD:\(fileName):\(base64String.prefix(100))..."
//                    self.connection.invoke(method: method, message, chatId, fileName) { error in
//                        if let error = error {
//                            print("❌ \(method) failed: \(error)")
//                            tryMethod(index: index + 1)
//                        } else {
//                            print("✅ File sent via \(method)")
//                            promise(.success(true))
//                        }
//                    }
//                } else {
//                    // For file-specific methods
//                    self.connection.invoke(method: method, base64String, fileName, chatId) { error in
//                        if let error = error {
//                            print("❌ \(method) failed: \(error)")
//                            tryMethod(index: index + 1)
//                        } else {
//                            print("✅ File sent via \(method)")
//                            promise(.success(true))
//                        }
//                    }
//                }
//            }
//            
//            tryMethod(index: 0)
//        }
//        .eraseToAnyPublisher()
//    }
//    
//}
