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
    }
    
