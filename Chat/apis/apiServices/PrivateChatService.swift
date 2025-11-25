//
//  NetworkService.swift
//  Chat
//
//  Created by Ahmed Elhussieny on 23/11/2025.
//


import Foundation
import Combine
class PrivateChatService:AuthHeaderAdding {
    static let shared = PrivateChatService()
    let baseURL = Utilities.baseURL
    
    // Remove the stored token property and always read from UserDefaults
     var token: String? {
        return UserDefaults.standard.string(forKey: "authToken")
    }
    private init() {}
    func createPrivateChat(with userId: String) -> AnyPublisher<ChatResponse, Error> {
        guard let url = URL(string: "\(baseURL)/api/Chat/PrivateChat") else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeaders(to: &urlRequest)
        
        print("💬 Creating private chat with user: \(userId)")
        
        // Try sending the user ID as a raw string
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
