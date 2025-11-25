import Foundation
import Combine
class SendMsgService:AuthHeaderAdding {
    static let shared = SendMsgService()
    let baseURL = Utilities.baseURL
    
    // Always read from UserDefaults
    var token: String? {
        return UserDefaults.standard.string(forKey: "authToken")
    }
    private init() {}
    func sendMessage(_ request: SendMessageRequest) -> AnyPublisher<String, Error> {
        guard let url = URL(string: "\(baseURL)/api/SignalR/SendMessage") else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeaders(to: &urlRequest)
        
        print("📤 Sending message: '\(request.Message)' to chat: \(request.chatId)")
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
            
            // Print the request for debugging
            if let jsonString = String(data: urlRequest.httpBody!, encoding: .utf8) {
                print("📦 Send Message Request: \(jsonString)")
            }
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: urlRequest)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }
                
                print("📡 Send Message Response: \(httpResponse.statusCode)")
                
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📦 Send Message Response Body: \(responseString)")
                }
                
                // Handle 401 specifically
                if httpResponse.statusCode == 401 {
                    print("🔐 Authentication failed for SendMessage - clearing token")
                    UserDefaults.standard.removeObject(forKey: "authToken")
                    //throw NetworkError.authenticationError
                }
                
                if httpResponse.statusCode == 200 {
                    return "Message sent successfully"
                } else {
                    // Try to get more specific error message
                    if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMessage = errorResponse["message"] as? String {
                        throw NetworkError.serverError(errorMessage)
                    } else {
                        throw NetworkError.serverError("Failed to send message: \(httpResponse.statusCode)")
                    }
                }
            }
            .eraseToAnyPublisher()
    }
    
}
