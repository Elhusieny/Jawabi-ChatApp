//
//  GroupRoomServiceProtocol.swift
//  Chat
//
//  Created by Ahmed Elhussieny on 23/11/2025.
//


import Combine
import Foundation
import UIKit

// MARK: - Group Room Service Protocol
protocol GroupRoomServiceProtocol {
    func createRoom(_ request: CreateRoomRequest) -> AnyPublisher<CreateRoomResponse, Error>
}

// GroupRoomService.swift - Updated version


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
        
        print("🚀 Creating room with name: \(request.name)")
        print("👥 Members: \(request.memberIds)")
        print("📸 Has image: \(request.chatPicture != nil)")
        print("📸 Image length: \(request.chatPicture?.count ?? 0)")
        
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
        
        // Add ChatPicture as a file upload, not as a string field
        if let chatPictureBase64 = request.chatPicture, !chatPictureBase64.isEmpty {
            // Convert base64 back to image data
            if let imageData = Data(base64Encoded: chatPictureBase64) {
                body.append("--\(boundary)\r\n")
                body.append("Content-Disposition: form-data; name=\"ChatPicture\"; filename=\"group_avatar.jpg\"\r\n")
                body.append("Content-Type: image/jpeg\r\n\r\n")
                body.append(imageData)
                body.append("\r\n")
                print("📸 Added image file to multipart form data, size: \(imageData.count) bytes")
            } else {
                print("❌ Failed to convert base64 to image data")
            }
        }
        
        // Add MemberIds array
        for memberId in request.memberIds {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"MemberIds\"\r\n\r\n")
            body.append("\(memberId)\r\n")
        }
        
        // Close the form data
        body.append("--\(boundary)--\r\n")
        
        print("📦 Total multipart body size: \(body.count) bytes")
        return body
    }
}
