import Foundation
import UIKit
import Alamofire
import Combine

// MARK: - Profile Picture Service Protocol
protocol ProfilePictureServiceProtocol {
    /// Uploads a profile picture for the current user
    func uploadProfilePicture(_ image: UIImage) -> AnyPublisher<ProfilePictureResponse, Error>
    
    /// Retrieves the current user's profile information
    func getUserProfile() -> AnyPublisher<UserProfile, Error>
    
    /// Updates the current user's profile information
    func updateUserProfile(name: String?, email: String?, phoneNumber: String?) -> AnyPublisher<UserProfile, Error>
}

// MARK: - Profile Picture Service
/// Service responsible for managing user profile pictures and profile information
class ProfilePictureService: ProfilePictureServiceProtocol {
    /// Shared singleton instance
    static let shared = ProfilePictureService()
    
    /// Base URL for API endpoints
    private let baseURL = Utilities.baseURL
    
    /// Private initializer for singleton pattern
    private init() {}
    
    // MARK: - Get User Profile
    
    /// Fetches the current user's profile information
    /// - Returns: A publisher that emits a UserProfile or an error
    func getUserProfile() -> AnyPublisher<UserProfile, Error> {
        guard let token = UserDefaults.standard.string(forKey: "authToken") else {
            return Fail(error: NetworkError.authenticationError).eraseToAnyPublisher()
        }
        
        let url = "\(baseURL)/api/Chat/profile"
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        
        return Future<UserProfile, Error> { promise in
            AF.request(url, method: .get, headers: headers)
                .validate()
                .responseDecodable(of: UserProfile.self) { response in
                    switch response.result {
                    case .success(let userProfile):
                        promise(.success(userProfile))
                    case .failure(let error):
                        promise(.failure(error))
                    }
                }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Upload Profile Picture
    
    /// Uploads a new profile picture for the current user
    /// - Parameter image: The UIImage to set as profile picture
    /// - Returns: A publisher that emits a ProfilePictureResponse or an error
    func uploadProfilePicture(_ image: UIImage) -> AnyPublisher<ProfilePictureResponse, Error> {
        guard let token = UserDefaults.standard.string(forKey: "authToken") else {
            return Fail(error: NetworkError.authenticationError).eraseToAnyPublisher()
        }

        let url = "\(baseURL)/api/Account/UpdateProfilePicture"
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)",
            "Accept": "application/json"
        ]
        
        return Future<ProfilePictureResponse, Error> { promise in
            // Convert UIImage to Data
            guard let imageData = image.jpegData(compressionQuality: 0.7) else {
                promise(.failure(NetworkError.invalidImageData))
                return
            }
            
            // Create multipart form data for upload
            AF.upload(multipartFormData: { multipartFormData in
                multipartFormData.append(imageData,
                                       withName: "ProfilePicture",  // Must match backend parameter name
                                       fileName: "profile_\(Date().timeIntervalSince1970).jpg",
                                       mimeType: "image/jpeg")
            }, to: url, method: .patch, headers: headers)
            .validate()
            .uploadProgress { progress in
                print("📤 Upload Progress: \(Int(progress.fractionCompleted * 100))%")
            }
            .responseData { response in
                switch response.result {
                case .success(let data):
                    do {
                        // Parse as ProfilePictureResponse (token + message)
                        let decoder = JSONDecoder()
                        let result = try decoder.decode(ProfilePictureResponse.self, from: data)
                        
                        print("✅ Upload response: \(result.message ?? "No message")")
                        
                        // Save new token if provided
                        if let newToken = result.token {
                            UserDefaults.standard.set(newToken, forKey: "authToken")
                            print("🔄 Token updated after profile picture upload")
                        }
                        
                        promise(.success(result))
                    } catch {
                        print("❌ JSON parsing error: \(error)")
                        print("📄 Raw response: \(String(data: data, encoding: .utf8) ?? "No response")")
                        
                        // Try alternative response format if standard parsing fails
                        if let responseString = String(data: data, encoding: .utf8),
                           responseString.lowercased().contains("success") ||
                           responseString.lowercased().contains("updated") {
                            let successResponse = ProfilePictureResponse(
                                token: nil,
                                message: "Profile picture updated successfully!"
                            )
                            promise(.success(successResponse))
                        } else {
                            promise(.failure(error))
                        }
                    }
                    
                case .failure(let error):
                    print("❌ Upload failed: \(error)")
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    
    // MARK: - Update User Profile Info
    func updateUserProfile(name: String?, email: String?, phoneNumber: String?) -> AnyPublisher<UserProfile, Error> {
        guard let token = UserDefaults.standard.string(forKey: "authToken") else {
            return Fail(error: NetworkError.authenticationError).eraseToAnyPublisher()
        }
        
        let url = "\(baseURL)/api/Account/UpdateProfile"
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        
        var parameters: [String: Any] = [:]
        if let name = name, !name.isEmpty {
            parameters["Name"] = name
        }
        if let email = email, !email.isEmpty {
            parameters["Email"] = email
        }
        if let phoneNumber = phoneNumber, !phoneNumber.isEmpty {
            parameters["PhoneNumber"] = phoneNumber
        }
        
        return Future<UserProfile, Error> { promise in
            AF.request(url, method: .patch, parameters: parameters, encoding: JSONEncoding.default, headers: headers)
                .validate()
                .responseDecodable(of: UserProfile.self) { response in
                    switch response.result {
                    case .success(let userProfile):
                        promise(.success(userProfile))
                    case .failure(let error):
                        promise(.failure(error))
                    }
                }
        }
        .eraseToAnyPublisher()
    }
}

