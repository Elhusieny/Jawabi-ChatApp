import Foundation
import Combine
class GetAllChatsService:AuthHeaderAdding {
    static let shared = GetAllChatsService()
    let baseURL = Utilities.baseURL
    
    // Always read from UserDefaults
       var token: String? {
           return UserDefaults.standard.string(forKey: "authToken")
       }
        private init() {}
   
        
        // MARK: - Get Chat
        func getChat(_ chatId: Int) -> AnyPublisher<Chat, Error> {
            guard let url = URL(string: "\(baseURL)/api/Chat/GetChat/\(chatId)") else {
                return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
            }
            
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "GET"
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            addAuthHeaders(to: &urlRequest) // Add auth header
            
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

        
   
    /// Fetches all chats for the current user with their last message
    func getAllChats() -> AnyPublisher<[Chat], Error> {
        // Try adding token as query parameter (like SignalR)
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
        // Also add as header for redundancy
        addAuthHeaders(to: &urlRequest)
        
        // Verify token is present
        if let token = self.token {
            print("🔑 Token exists: \(token.prefix(20))...")
        } else {
            print("❌ No token found in UserDefaults!")
        }
        
        // Verify authorization header was added
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
                    // Create a Message from lastMessage if it exists
                    var messages: [Message] = []
                    if let lastMsg = summary.lastMessage {
                        let message = Message(
                            id: 0, // Temporary ID
                            text: lastMsg.text,
                            name: summary.name, // We don't know the sender, use chat name
                            timestamp: lastMsg.time
                        )
                        messages.append(message)
                    }
                    
                    return Chat(
                        id: summary.id,
                        name: summary.name,
                        pictureUrl: summary.pictureUrl,
                        type: summary.type,
                        messages: messages,
                        users: [] // We'll get users when we fetch the full chat
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
    
