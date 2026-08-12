//
//  AddMembersServiceProtocol.swift
//  Chat
//
//  Created by Ahmed Elhussieny on 12/05/2026.
//


// AddMembersService.swift
import Foundation
import Combine
import Alamofire

protocol AddMembersServiceProtocol {
    func addMembers(chatId: Int, memberIds: [String]) -> AnyPublisher<AddMembersResponse, Error>
}

class AddMembersService: AddMembersServiceProtocol {
    static let shared = AddMembersService()
    var baseURL: String {
        return Utilities.baseURL
    }
    private init() {}
    
    func addMembers(chatId: Int, memberIds: [String]) -> AnyPublisher<AddMembersResponse, Error> {
        guard let token = UserDefaults.standard.string(forKey: "authToken") else {
            return Fail(error: NSError(domain: "Auth", code: 401, 
                userInfo: [NSLocalizedDescriptionKey: "No authentication token"]))
                .eraseToAnyPublisher()
        }
        
        guard let url = URL(string: "\(baseURL)/api/Chat/AddMembers") else {
            return Fail(error: NSError(domain: "Network", code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
                .eraseToAnyPublisher()
        }
        
        let parameters: [String: Any] = [
            "chatId": chatId,
            "members": memberIds
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
        
        print("📤 Adding members to chat \(chatId): \(memberIds)")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }
                
                print("📡 Add Members Response: \(httpResponse.statusCode)")
                
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📦 Response: \(responseString)")
                }
                
                guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
                    throw NetworkError.serverError("Failed to add members: \(httpResponse.statusCode)")
                }
                
                return data
            }
            .decode(type: AddMembersResponse.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
}

// MARK: - Response Model
struct AddMembersResponse: Codable {
    let message: String?
    let success: Bool?
    let addedMembers: [String]?
    let failedMembers: [String]?
    
    var isSuccess: Bool {
        return success == true || message?.lowercased().contains("success") == true
    }
}
