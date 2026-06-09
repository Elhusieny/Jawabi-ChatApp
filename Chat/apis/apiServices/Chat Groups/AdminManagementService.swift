
import Foundation
import Combine

class AdminManagementService {
    static let shared = AdminManagementService()
    
    private let baseURL = "http://158.220.90.131:8444"
    
    // MARK: - Promote to Admin
    func promoteToAdmin(chatId: Int, targetUserId: String) -> AnyPublisher<Void, Error> {
        let endpoint = "\(baseURL)/api/chat/PromoteToAdmin"
        
        guard let url = URL(string: endpoint) else {
            return Fail(error: NSError(domain: "InvalidURL", code: -1)).eraseToAnyPublisher()
        }
        
        let dto = PromoteToAdminRequest(chatId: chatId, targetUserId: targetUserId)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add auth token
        if let token = UserDefaults.standard.string(forKey: "authToken") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            request.httpBody = try JSONEncoder().encode(dto)
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .mapError { $0 as Error }
            .map { _ in () }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Remove Admin
    func removeAdmin(chatId: Int, targetUserId: String) -> AnyPublisher<Void, Error> {
        let endpoint = "\(baseURL)/api/chat/RemoveAdmin"
        
        guard let url = URL(string: endpoint) else {
            return Fail(error: NSError(domain: "InvalidURL", code: -1)).eraseToAnyPublisher()
        }
        
        let dto = RemoveAdminRequest(chatId: chatId, targetUserId: targetUserId)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add auth token
        if let token = UserDefaults.standard.string(forKey: "authToken") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            request.httpBody = try JSONEncoder().encode(dto)
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .mapError { $0 as Error }
            .map { _ in () }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Remove Member
    func removeMember(chatId: Int, targetUserId: String) -> AnyPublisher<Void, Error> {
        let endpoint = "\(baseURL)/api/chat/RemoveMember"
        
        guard let url = URL(string: endpoint) else {
            return Fail(error: NSError(domain: "InvalidURL", code: -1)).eraseToAnyPublisher()
        }
        
        let dto = RemoveMemberRequest(chatId: chatId, targetUserId: targetUserId)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add auth token
        if let token = UserDefaults.standard.string(forKey: "authToken") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            request.httpBody = try JSONEncoder().encode(dto)
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .mapError { $0 as Error }
            .map { _ in () }
            .eraseToAnyPublisher()
    }
}

// MARK: - Request DTOs

struct PromoteToAdminRequest: Codable {
    let chatId: Int
    let targetUserId: String
    
    enum CodingKeys: String, CodingKey {
        case chatId = "ChatId"
        case targetUserId = "TargetUserId"
    }
}

struct RemoveAdminRequest: Codable {
    let chatId: Int
    let targetUserId: String
    
    enum CodingKeys: String, CodingKey {
        case chatId = "ChatId"
        case targetUserId = "TargetUserId"
    }
}

struct RemoveMemberRequest: Codable {
    let chatId: Int
    let targetUserId: String
    
    enum CodingKeys: String, CodingKey {
        case chatId = "ChatId"
        case targetUserId = "TargetUserId"
    }
}

// MARK: - Response Models

struct UserPromotedEvent: Codable {
    let chatId: Int
    let userId: String
    let newRole: String
}

struct UserRoleChangedEvent: Codable {
    let chatId: Int
    let userId: String
    let role: Int // 0 = admin, 1 = member
}
