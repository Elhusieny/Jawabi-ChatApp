import Foundation
import Combine

/// Service responsible for handling file uploads to the server and SignalR integration
class FileUploadService {
    /// Shared singleton instance
    static let shared = FileUploadService()
    
    /// Private initializer for singleton pattern
    private init() {}
    
    /// Uploads a file to the server using multipart form data
    /// - Parameters:
    ///   - data: The file data to upload
    ///   - fileName: The name of the file
    ///   - chatId: The ID of the chat where the file will be shared
    /// - Returns: A publisher that emits the file URL as a string, or an error
    func uploadFileToServer(
        _ data: Data,
        fileName: String,
        chatId: Int
    ) -> AnyPublisher<String, Error> {
        
        return Future<String, Error> { promise in
            guard let token = UserDefaults.standard.string(forKey: "authToken") else {
                promise(.failure(NSError(domain: "Auth", code: 401,
                    userInfo: [NSLocalizedDescriptionKey: "No authentication token"])))
                return
            }
            
            print("📤 Uploading file via HTTP to /api/Chat/upload")
            print("   File: \(fileName)")
            print("   Size: \(data.count) bytes")
            print("   Chat ID: \(chatId)")
            
            // Use the exact endpoint from JavaScript client
            let baseUrl = "http://158.220.90.131:8444"
            let uploadUrl = "\(baseUrl)/api/Chat/upload"
            
            var request = URLRequest(url: URL(string: uploadUrl)!)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            // Create multipart form data matching JavaScript implementation
            let boundary = UUID().uuidString
            request.setValue("multipart/form-data; boundary=\(boundary)",
                           forHTTPHeaderField: "Content-Type")
            
            var body = Data()
            
            // Add file data with key "file" (matches JavaScript)
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
            
            // Set proper content type based on file extension
            let mimeType = self.mimeType(for: fileName)
            body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
            
            body.append(data)
            body.append("\r\n".data(using: .utf8)!)
            
            // Close boundary
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
            
            request.httpBody = body
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("❌ HTTP upload failed: \(error)")
                    promise(.failure(error))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ No valid response")
                    promise(.failure(NSError(domain: "Upload", code: 500,
                        userInfo: [NSLocalizedDescriptionKey: "No response from server"])))
                    return
                }
                
                print("📊 HTTP Status: \(httpResponse.statusCode)")
                
                if let data = data {
                    if httpResponse.statusCode == 200 {
                        do {
                            // Parse JSON response for file URL
                            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                                print("📦 Upload response JSON: \(json)")
                                
                                if let fileUrl = json["url"] as? String {
                                    print("✅ File uploaded successfully: \(fileUrl)")
                                    promise(.success(fileUrl))
                                } else {
                                    print("⚠️ No 'url' field in response")
                                    promise(.failure(NSError(domain: "Upload", code: 500,
                                        userInfo: [NSLocalizedDescriptionKey: "No URL in server response"])))
                                }
                            } else {
                                let responseString = String(data: data, encoding: .utf8) ?? "No response"
                                print("📄 Raw response: \(responseString)")
                                promise(.failure(NSError(domain: "Upload", code: 500,
                                    userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response"])))
                            }
                        } catch {
                            print("❌ JSON parse error: \(error)")
                            promise(.failure(error))
                        }
                    } else {
                        let responseString = String(data: data, encoding: .utf8) ?? "No response"
                        print("❌ Server error \(httpResponse.statusCode): \(responseString)")
                        promise(.failure(NSError(domain: "Upload", code: httpResponse.statusCode,
                            userInfo: [NSLocalizedDescriptionKey: "Server error: \(httpResponse.statusCode)"])))
                    }
                } else {
                    promise(.failure(NSError(domain: "Upload", code: 500,
                        userInfo: [NSLocalizedDescriptionKey: "Empty response"])))
                }
            }.resume()
        }
        .eraseToAnyPublisher()
    }
    
    /// Sends the uploaded file URL via SignalR to notify other chat participants
    /// - Parameters:
    ///   - fileUrl: The URL of the uploaded file
    ///   - fileName: The name of the file
    ///   - chatId: The ID of the chat where the file was shared
    ///   - signalRService: The SignalR service instance for sending messages
    /// - Returns: A publisher that emits true if successful, or an error
    func sendFileUrlViaSignalR(
        _ fileUrl: String,
        fileName: String,
        chatId: Int,
        signalRService: SignalRService
    ) -> AnyPublisher<Bool, Error> {
        
        return Future<Bool, Error> { promise in
            print("📤 Sending file URL via SignalR")
            print("   URL: \(fileUrl)")
            print("   File: \(fileName)")
            print("   Chat ID: \(chatId)")
            
            // Match JavaScript implementation: send with message "Sent a file" and URL as photoUrl
            signalRService.connection.invoke(
                method: "SendPrivateMessage",
                "Sent a file",  // Message text (matches JavaScript)
                chatId,         // Chat ID
                fileUrl         // File URL as photoUrl parameter
            ) { error in
                if let error = error {
                    print("❌ SignalR send failed: \(error)")
                    promise(.failure(error))
                } else {
                    print("✅ File URL sent via SignalR")
                    promise(.success(true))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// Determines the MIME type based on file extension
    /// - Parameter fileName: The name of the file
    /// - Returns: The appropriate MIME type string
    private func mimeType(for fileName: String) -> String {
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
        default: return "application/octet-stream"
        }
    }
}
