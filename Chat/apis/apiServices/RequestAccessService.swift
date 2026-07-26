//
//  RequestAccessService.swift
//  Chat
//
//  Created by Ahmed Elhussieny on 06/07/2026.
//

import Foundation
import Combine

class RequestAccessService {
    
    static let shared = RequestAccessService()
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    func requestAccess(_ request: RequestAccessRequest) -> AnyPublisher<String, Error> {
        let serverURL = request.serverUrl ?? ServerConfigManager.shared.activeServerURL
        let urlString = "\(serverURL)/api/Account/RequestAccess"
        
        guard let url = URL(string: urlString) else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        let parameters = [
            "UserName": request.userName,
            "Email": request.email,
            "DisplayName": request.displayName,
            "PhoneNumber": request.phoneNumber,
            "Password": request.password,
            "CompanyName": request.companyName
        ]
        
        for (key, value) in parameters {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        
        if let profilePicture = request.profilePicture {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"ProfilePicture\"; filename=\"profile.jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(profilePicture)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        urlRequest.httpBody = body
        
        return URLSession.shared.dataTaskPublisher(for: urlRequest)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }
                
                guard httpResponse.statusCode == 200 else {
                    if let errorString = String(data: data, encoding: .utf8) {
                        throw NetworkError.serverError(errorString)
                    }
                    throw NetworkError.serverError("Request access failed")
                }
                
                return String(data: data, encoding: .utf8) ?? "Request access successful"
            }
            .eraseToAnyPublisher()
    }
}
