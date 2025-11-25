//
//  GroupRoomServiceProtocol.swift
//  Chat
//
//  Created by Ahmed Elhussieny on 23/11/2025.
//


import Combine
import Foundation

// MARK: - Group Room Service Protocol
protocol GroupRoomServiceProtocol {
    func createRoom(_ request: CreateRoomRequest) -> AnyPublisher<CreateRoomResponse, Error>
}

// MARK: - Group Room Service
class GroupRoomService: GroupRoomServiceProtocol {
    static let shared = GroupRoomService()
    private let baseURL = "http://158.220.90.131:8444/api/Chat"
    
    private init() {}
    
    func createRoom(_ request: CreateRoomRequest) -> AnyPublisher<CreateRoomResponse, Error> {
        guard let url = URL(string: "\(baseURL)/CreateRoom") else {
            return Fail(error: NetworkError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        
        // Create multipart form data
        let boundary = "Boundary-\(UUID().uuidString)"
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Add authentication token
        if let token = AuthService.shared.getAuthToken() {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let httpBody = createMultipartFormData(boundary: boundary, request: request)
        urlRequest.httpBody = httpBody
        
        // Print request details for debugging
        print("🚀 Creating room with name: \(request.name)")
        print("👥 Members: \(request.memberIds)")
        print("📸 Has image: \(request.chatPicture != nil)")
        
        return URLSession.shared.dataTaskPublisher(for: urlRequest)
            .tryMap { data, response in
                // Print response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📡 Raw response: \(responseString)")
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }
                
                print("📊 Response status code: \(httpResponse.statusCode)")
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    if httpResponse.statusCode == 401 {
                        throw NetworkError.unauthorized
                    }
                    throw NetworkError.httpError(httpResponse.statusCode)
                }
                
                return data
            }
            .decode(type: CreateRoomResponse.self, decoder: JSONDecoder())
            .mapError { error in
                print("❌ Decoding error: \(error)")
                if let networkError = error as? NetworkError {
                    return networkError
                }
                return NetworkError.decodingError(error)
            }
            .eraseToAnyPublisher()
    }
    
    private func createMultipartFormData(boundary: String, request: CreateRoomRequest) -> Data {
        var body = Data()
        
        // Add Name field
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"Name\"\r\n\r\n")
        body.append("\(request.name)\r\n")
        
        // Add ChatPicture field if provided
        if let chatPicture = request.chatPicture {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"chatPicture\"\r\n\r\n")
            body.append("\(chatPicture)\r\n")
        }
        
        // Add MemberIds array
        for memberId in request.memberIds {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"memberIds\"\r\n\r\n")
            body.append("\(memberId)\r\n")
        }
        
        // Close the form data
        body.append("--\(boundary)--\r\n")
        
        return body
    }
}
