import Foundation
import Alamofire
import Combine

class FileUploadService {
    static let shared = FileUploadService()
    private let baseURL = "http://158.220.90.131:8444"
    
    struct UploadResponse: Codable {
        let url: String
        let fileName: String
        let size: Int
        let message: String?
    }
    
    func uploadFile(_ data: Data, fileName: String, completion: @escaping (Result<UploadResponse, Error>) -> Void) {
        guard let token = UserDefaults.standard.string(forKey: "authToken") else {
            completion(.failure(NSError(domain: "FileUpload", code: 401, userInfo: [NSLocalizedDescriptionKey: "Authentication required"])))
            return
        }
        
        let url = "\(baseURL)/api/upload/file"
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "multipart/form-data"
        ]
        
        AF.upload(
            multipartFormData: { multipartFormData in
                multipartFormData.append(data, withName: "file", fileName: fileName)
            },
            to: url,
            method: .post,
            headers: headers
        )
        .validate()
        .responseDecodable(of: UploadResponse.self) { response in
            switch response.result {
            case .success(let uploadResponse):
                completion(.success(uploadResponse))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}