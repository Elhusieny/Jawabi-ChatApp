/// Service responsible for uploading images to the server

import UIKit
class ImageUploadService {
    /// Shared singleton instance
    static let shared = ImageUploadService()
    
    /// Base URL for the server
    private let baseUrl = "http://158.220.90.131:8444"
    
    /// Uploads an image to the server
    /// - Parameters:
    ///   - image: The UIImage to upload
    ///   - completion: Callback with Result containing ImageUploadResponse or Error
    func uploadImage(_ image: UIImage, completion: @escaping (Result<ImageUploadResponse, Error>) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            completion(.failure(NSError(domain: "ImageUploadService", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])))
            return
        }
        
        guard let token = UserDefaults.standard.string(forKey: "authToken") else {
            completion(.failure(NSError(domain: "ImageUploadService", code: -2,
                userInfo: [NSLocalizedDescriptionKey: "No auth token"])))
            return
        }
        
        guard let url = URL(string: "\(baseUrl)/api/Chat/upload") else {
            completion(.failure(NSError(domain: "ImageUploadService", code: -3,
                userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        // Create multipart request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // Setup multipart form data
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add image data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        // Perform request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "ImageUploadService", code: -4,
                    userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            // Debug logging
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 Upload Response: \(responseString)")
            }
            
            // Decode response
            do {
                let uploadResponse = try JSONDecoder().decode(ImageUploadResponse.self, from: data)
                completion(.success(uploadResponse))
            } catch {
                print("❌ Decode error: \(error)")
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
}


/// Response model for image upload operations
struct ImageUploadResponse: Codable {
    /// Name of the uploaded file
    let fileName: String
    
    /// URL where the uploaded image can be accessed
    let url: String
}
