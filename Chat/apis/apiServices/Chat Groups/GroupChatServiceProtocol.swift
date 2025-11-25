import Combine
import Foundation

// MARK: - Group Chat Service Protocol
protocol GroupChatServiceProtocol {
    func createRoom(_ request: CreateRoomRequest) -> AnyPublisher<CreateRoomResponse, Error>
    func joinRoom(roomId: Int) -> AnyPublisher<JoinRoomResponse, Error>
    func getRoomDetails(roomId: Int) -> AnyPublisher<GroupRoom, Error>
    func getGroupRooms() -> AnyPublisher<[GroupRoom], Error>
}

// MARK: - Group Chat Service
class GroupChatService: GroupChatServiceProtocol {
    static let shared = GroupChatService()
    private let baseURL = "http://184.174.37.115:8444/api/Chat"
    
    private init() {}
    
    // MARK: - Create Room
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
        
        // Add authentication token if needed
        if let token = AuthService.shared.getAuthToken() {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let httpBody = createMultipartFormData(boundary: boundary, request: request)
        urlRequest.httpBody = httpBody
        
        return URLSession.shared.dataTaskPublisher(for: urlRequest)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }
                
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
                if let networkError = error as? NetworkError {
                    return networkError
                }
                return NetworkError.decodingError(error)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Join Room
    func joinRoom(roomId: Int) -> AnyPublisher<JoinRoomResponse, Error> {
        guard let url = URL(string: "\(baseURL)/join/\(roomId)") else {
            return Fail(error: NetworkError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthService.shared.getAuthToken() {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return URLSession.shared.dataTaskPublisher(for: urlRequest)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    if httpResponse.statusCode == 401 {
                        throw NetworkError.unauthorized
                    }
                    throw NetworkError.httpError(httpResponse.statusCode)
                }
                
                return data
            }
            .decode(type: JoinRoomResponse.self, decoder: JSONDecoder())
            .mapError { error in
                if let networkError = error as? NetworkError {
                    return networkError
                }
                return NetworkError.decodingError(error)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Get Room Details
    func getRoomDetails(roomId: Int) -> AnyPublisher<GroupRoom, Error> {
        guard let url = URL(string: "\(baseURL)/room/\(roomId)") else {
            return Fail(error: NetworkError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        
        if let token = AuthService.shared.getAuthToken() {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return URLSession.shared.dataTaskPublisher(for: urlRequest)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    if httpResponse.statusCode == 401 {
                        throw NetworkError.unauthorized
                    }
                    throw NetworkError.httpError(httpResponse.statusCode)
                }
                
                return data
            }
            .decode(type: GroupRoom.self, decoder: JSONDecoder())
            .mapError { error in
                if let networkError = error as? NetworkError {
                    return networkError
                }
                return NetworkError.decodingError(error)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Get Group Rooms
    func getGroupRooms() -> AnyPublisher<[GroupRoom], Error> {
        guard let url = URL(string: "\(baseURL)/groups") else {
            return Fail(error: NetworkError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        
        if let token = AuthService.shared.getAuthToken() {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return URLSession.shared.dataTaskPublisher(for: urlRequest)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    if httpResponse.statusCode == 401 {
                        throw NetworkError.unauthorized
                    }
                    throw NetworkError.httpError(httpResponse.statusCode)
                }
                
                return data
            }
            .decode(type: [GroupRoom].self, decoder: JSONDecoder())
            .mapError { error in
                if let networkError = error as? NetworkError {
                    return networkError
                }
                return NetworkError.decodingError(error)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Private Helper Methods
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

