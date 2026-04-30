
//
//  NetworkService.swift
//  Chat
//
//  Created by Ahmed Elhussieny on 23/11/2025.
//

import Foundation
import Combine

/// Service responsible for creating private chats between users
class PrivateChatService: AuthHeaderAdding {
    /// Shared singleton instance
    static let shared = PrivateChatService()
    
    /// Base URL for API endpoints
    let baseURL = Utilities.baseURL
    
    /// Computed property to retrieve authentication token from UserDefaults
    var token: String? {
        return UserDefaults.standard.string(forKey: "authToken")
    }
    
    /// Private initializer for singleton pattern
    private init() {}
    
    /// Creates a private chat with another user
    /// - Parameter userId: The ID of the user to create a chat with
    /// - Returns: A publisher that emits a ChatResponse or an error
    func createPrivateChat(with userId: String) -> AnyPublisher<ChatResponse, Error> {
        guard let url = URL(string: "\(baseURL)/api/Chat/PrivateChat") else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeaders(to: &urlRequest)
        
        print("💬 Creating private chat with user: \(userId)")
        
        // Send user ID as raw string (matches server expectation)
        if let jsonData = "\"\(userId)\"".data(using: .utf8) {
            urlRequest.httpBody = jsonData
            print("📦 Sending raw string: \"\(userId)\"")
        } else {
            return Fail(error: NetworkError.serverError("Failed to create request body")).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: urlRequest)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }
                print("📡 Chat Creation Response: \(httpResponse.statusCode)")
                
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📦 Chat Response: \(responseString)")
                }
                
                if httpResponse.statusCode == 401 {
                    UserDefaults.standard.removeObject(forKey: "authToken")
                    // throw NetworkError.authenticationError
                }
                
                guard httpResponse.statusCode == 200 else {
                    throw NetworkError.serverError("Failed to create chat: \(httpResponse.statusCode)")
                }
                
                return data
            }
            .decode(type: ChatResponse.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
}


