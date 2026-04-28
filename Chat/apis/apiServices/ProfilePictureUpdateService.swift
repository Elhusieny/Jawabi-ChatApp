import Foundation
import UIKit
import Combine

class ProfilePictureUpdateService: AuthHeaderAdding {
    static let shared = ProfilePictureUpdateService()
    let baseURL = Utilities.baseURL
    
    var token: String? {
        return UserDefaults.standard.string(forKey: "authToken")
    }
    
    private init() {}
    
    /// Update profile picture and get new token
    func updateProfilePicture(_ image: UIImage) -> AnyPublisher<UpdateProfilePictureResponse, Error> {
        guard let url = URL(string: "\(baseURL)/api/Account/UpdateProfilePicture") else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }
        
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            return Fail(error: NetworkError.serverError("Failed to compress image"))
                .eraseToAnyPublisher()
        }
        
        return Future<UpdateProfilePictureResponse, Error> { promise in
            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            
            let boundary = UUID().uuidString
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            
            // Add auth header
            if let token = self.token {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            
            var body = Data()
            
            // Add image data
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"ProfilePicture\"; filename=\"profile.jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(imageData)
            body.append("\r\n".data(using: .utf8)!)
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
            
            request.httpBody = body
            
            print("📤 Uploading profile picture...")
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("❌ Profile picture upload error: \(error)")
                    promise(.failure(error))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    promise(.failure(NetworkError.invalidResponse))
                    return
                }
                
                print("📡 Profile picture upload response: \(httpResponse.statusCode)")
                
                guard httpResponse.statusCode == 200,
                      let data = data else {
                    if let data = data,
                       let errorMessage = String(data: data, encoding: .utf8) {
                        print("❌ Server error: \(errorMessage)")
                        promise(.failure(NetworkError.serverError(errorMessage)))
                    } else {
                        promise(.failure(NetworkError.serverError("Upload failed with status \(httpResponse.statusCode)")))
                    }
                    return
                }
                
                do {
                    let decoder = JSONDecoder()
                    let response = try decoder.decode(UpdateProfilePictureResponse.self, from: data)
                    print("✅ Profile picture uploaded successfully")
                    
                    // Update stored token if new one was returned
                    if let newToken = response.token {
                        print("🔑 Updating auth token with new profile picture URL")
                        UserDefaults.standard.set(newToken, forKey: "authToken")
                    }
                    
                    promise(.success(response))
                } catch {
                    print("❌ Failed to decode response: \(error)")
                    promise(.failure(error))
                }
            }.resume()
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - Response Models

struct UpdateProfilePictureResponse: Codable {
    let message: String
    let token: String?
    let pictureUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case message
        case token
        case pictureUrl
    }
}