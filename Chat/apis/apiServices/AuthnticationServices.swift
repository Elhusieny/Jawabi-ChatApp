import Foundation
import Combine

/// Service responsible for user authentication operations including registration and login
class AuthenticationServices {
    /// Shared singleton instance for global access
    static let shared = AuthenticationServices()
    
    /// Base URL for API endpoints from utilities configuration
    let baseURL = Utilities.baseURL
    
    /// Computed property that retrieves the authentication token from UserDefaults
    /// - Returns: The stored auth token if available, nil otherwise
    private var token: String? {
        return UserDefaults.standard.string(forKey: "authToken")
    }
    
    /// Private initializer to enforce singleton pattern
    private init() {}
    
    // MARK: - Authentication
    
    /// Registers a new user with the provided registration details
    /// - Parameter request: RegisterRequest containing user registration information
    /// - Returns: A publisher that emits a success message or an error
    func register(_ request: RegisterRequest) -> AnyPublisher<String, Error> {
        guard let url = URL(string: "\(baseURL)/api/Account/Register") else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        
        // Setup multipart form data for profile picture upload
        let boundary = "Boundary-\(UUID().uuidString)"
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add form fields to the multipart body
        let fields: [String: String] = [
            "UserName": request.userName,
            "Email": request.email,
            "DisplayName": request.displayName,
            "PhoneNumber": request.phoneNumber,
            "Password": request.password,
            "ServerUrl": request.serverUrl ?? "http://158.220.90.131:8444" // Default server URL if not provided
        ]
        
        // Append form fields to body
        for (key, value) in fields {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.append("\(value)\r\n")
        }
        
        // Add profile picture if provided
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
                
                // Debug logging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Response: \(responseString)")
                }
                
                // Handle response based on status code
                switch httpResponse.statusCode {
                case 200:
                    return "Registration successful"
                case 400...499:
                    // Parse error message from response if available
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
       
    /// - Returns: A publisher that emits a LoginResponse containing auth token and user info
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
                    // Parse error message from response
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
