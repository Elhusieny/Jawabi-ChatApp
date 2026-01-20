import Foundation
import UIKit

class ImageUploadService {
    static let shared = ImageUploadService()
    private let baseUrl = "http://158.220.90.131:8444"
    
    func uploadImage(_ image: UIImage, completion: @escaping (Result<ImageUploadResponse, Error>) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            completion(.failure(NSError(domain: "ImageUploadService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])))
            return
        }
        
        guard let token = UserDefaults.standard.string(forKey: "authToken") else {
            completion(.failure(NSError(domain: "ImageUploadService", code: -2, userInfo: [NSLocalizedDescriptionKey: "No auth token"])))
            return
        }
        
        guard let url = URL(string: "\(baseUrl)/api/Chat/upload") else {
            completion(.failure(NSError(domain: "ImageUploadService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // Create boundary
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Create form data body
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
                completion(.failure(NSError(domain: "ImageUploadService", code: -4, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            // Debug: Print raw response
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 Upload Response: \(responseString)")
            }
            
            // Try to decode response
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

struct ImageUploadResponse: Codable {
    let fileName: String
    let url: String
}


