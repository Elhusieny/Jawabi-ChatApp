import Foundation
import Combine
class AuthnticationServices{
    static let shared = AuthnticationServices()
    let baseURL = Utilities.baseURL
    
    // Remove the stored token property and always read from UserDefaults
    private var token: String? {
        return UserDefaults.standard.string(forKey: "authToken")
    }
    
    private init() {}
    
    // MARK: - Authentication
    func register(_ request: RegisterRequest) -> AnyPublisher<String, Error> {
        guard let url = URL(string: "\(baseURL)/api/Account/Register") else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        
        let boundary = "Boundary-\(UUID().uuidString)"
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add form fields
        let fields: [String: String] = [
            "UserName": request.userName,
            "Email": request.email,
            "DisplayName": request.displayName,
            "PhoneNumber": request.phoneNumber,
            "Password": request.password
        ]
        
        for (key, value) in fields {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.append("\(value)\r\n")
        }
        
        // Add profile picture if exists
        if let imageData = request.profilePicture {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"ProfilePicture\"; filename=\"profile.jpg\"\r\n")
            body.append("Content-Type: image/jpeg\r\n\r\n")
            body.append(imageData)
            body.append("\r\n")
        }
        
        body.append("--\(boundary)--\r\n")
        urlRequest.httpBody = body
        
        return URLSession.shared.dataTaskPublisher(for: urlRequest)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }
                
                // Print response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Response: \(responseString)")
                }
                
                switch httpResponse.statusCode {
                case 200:
                    return "Registration successful"
                case 400...499:
                    // Try to parse error message from response
                    if let errorResponse = try? JSONDecoder().decode([String: String].self, from: data),
                       let errorMessage = errorResponse["message"] {
                        throw NetworkError.serverError(errorMessage)
                    } else {
                        throw NetworkError.serverError("Registration failed with status: \(httpResponse.statusCode)")
                    }
                default:
                    throw NetworkError.serverError("Server error: \(httpResponse.statusCode)")
                }
            }
            .eraseToAnyPublisher()
    }
    
    
    // MARK: - Authentication
    func login(userName: String, password: String) -> AnyPublisher<LoginResponse, Error> {
        guard let url = URL(string: "\(baseURL)/api/Account/Login") else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let request = LoginRequest(userName: userName, password: password, rememberMe: true)
        
        print("🔐 Sending login request for: \(userName)")
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: urlRequest)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }
                
                print("📡 Login Response Status: \(httpResponse.statusCode)")
                
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📦 Login Response: \(responseString)")
                }
                
                if httpResponse.statusCode == 200 {
                    return data
                } else {
                    // Try to extract error message from response
                    if let errorResponse = try? JSONDecoder().decode([String: String].self, from: data),
                       let errorMessage = errorResponse["message"] {
                        throw NetworkError.serverError(errorMessage)
                    } else {
                        throw NetworkError.serverError("Login failed with status: \(httpResponse.statusCode)")
                    }
                }
            }
            .decode(type: LoginResponse.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
}
