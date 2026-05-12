/// Service responsible for fetching chat data, including individual chats and all user chats

import Foundation
import Combine
class GetAllChatsService: AuthHeaderAdding {
    /// Shared singleton instance
    static let shared = GetAllChatsService()
    
    /// Base URL for API endpoints
    let baseURL = Utilities.baseURL
    
    /// Computed property to retrieve authentication token from UserDefaults
    var token: String? {
        return UserDefaults.standard.string(forKey: "authToken")
    }
    /// Private initializer for singleton pattern
    private init() {}
    
    // MARK: - Get Single Chat
    
    /// Fetches a specific chat by its ID
    /// - Parameter chatId: The ID of the chat to retrieve
    /// - Returns: A publisher that emits a Chat object or an error
    func getChat(_ chatId: Int) -> AnyPublisher<Chat, Error> {
        guard let url = URL(string: "\(baseURL)/api/Chat/GetChat/\(chatId)") else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeaders(to: &urlRequest) // Add authentication headers
        
        return URLSession.shared.dataTaskPublisher(for: urlRequest)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }
                
                print("📡 Get Chat Response: \(httpResponse.statusCode)")
                
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📦 Chat Data: \(responseString)")
                }
                
                guard httpResponse.statusCode == 200 else {
                    throw NetworkError.serverError("Failed to fetch chat: \(httpResponse.statusCode)")
                }
                
                return data
            }
            .decode(type: Chat.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    // MARK: - Get All Chats
    
    /// Fetches all chats for the current user with their last message
    /// - Returns: A publisher that emits an array of Chat objects or an error
    func getAllChats() -> AnyPublisher<[Chat], Error> {
        // Add token as query parameter (like SignalR) for redundancy
        guard let token = self.token else {
            return Fail(error: NetworkError.serverError("No auth token")).eraseToAnyPublisher()
        }
        
        let urlString = "\(baseURL)/api/Chat/GetChatsWithLastMessage?access_token=\(token)"
        
        guard let url = URL(string: urlString) else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Add as header as well for redundancy
        addAuthHeaders(to: &urlRequest)
        
        // Debug token presence
        if let token = self.token {
            print("🔑 Token exists: \(token.prefix(20))...")
        } else {
            print("❌ No token found in UserDefaults!")
        }
        
        // Verify authorization header
        if let authHeader = urlRequest.value(forHTTPHeaderField: "Authorization") {
            print("✅ Authorization header added: \(authHeader.prefix(30))...")
        } else {
            print("❌ Authorization header NOT added!")
        }
        
        print("🌐 Fetching all chats from: \(url.absoluteString)")
        
        return URLSession.shared.dataTaskPublisher(for: urlRequest)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }
                
                print("📡 Get All Chats Response: \(httpResponse.statusCode)")
                
                
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📦 Chats Data: \(responseString.prefix(500))...")
                    print("all chats \(responseString)")

                }
                guard httpResponse.statusCode == 200 else {
                    throw NetworkError.serverError("Failed to fetch chats: \(httpResponse.statusCode)")
                }
                
                return data
            }
            .decode(type: [ChatSummary].self, decoder: JSONDecoder())
            .map { summaries in
                // Convert ChatSummary to Chat model
                return summaries.map { summary in
                        var messages: [Message] = []
                        if let lastMsg = summary.lastMessage {
                            messages.append(Message(
                                id: 0,
                                            displayText: lastMsg.text,
                                name: summary.name ?? "Unknown",
                                timestamp: lastMsg.time
                            ))
                        }
                    
                    return Chat(
                               id: summary.id,
                               name: summary.name ?? "Unknown",
                               pictureUrl: summary.pictureUrl ?? "",
                               type: summary.type ?? 1,
                               messages: messages,
                               users: [],
                               unreadCount: summary.unreadCount ?? 0,
                               isOnline: summary.isOnline ?? false
                           )
                       }
            }
            .catch { error -> AnyPublisher<[Chat], Error> in
                print("❌ Failed to fetch/decode chats: \(error)")
                return Fail(error: error).eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
}

