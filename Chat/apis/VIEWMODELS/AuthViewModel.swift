import Combine
import SwiftUI

class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentUser: String?
    
    private var cancellables = Set<AnyCancellable>()
    private let authnticationServices = AuthnticationServices.shared
    
    func login(userName: String, password: String) {
        isLoading = true
        errorMessage = nil
        
        AuthnticationServices.shared.login(userName: userName, password: password)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                switch completion {
                case .failure(let error):
                    self?.errorMessage = "Login failed: \(error.localizedDescription)"
                    print("❌ Login error: \(error)")
                    self?.isAuthenticated = false
                case .finished:
                    print("✅ Login completed successfully")
                }
            } receiveValue: { [weak self] response in
                print("✅ Login successful for: \(response.userName ?? "unknown")")
                self?.isAuthenticated = true
                
                // Store the actual username from the response
                if let userName = response.userName {
                    self?.currentUser = userName
                    UserDefaults.standard.set(userName, forKey: "currentUsername")
                    print("👤 Stored username: \(userName)")
                } else {
                    // Fallback to the entered username
                    self?.currentUser = userName
                    UserDefaults.standard.set(userName, forKey: "currentUsername")
                    print("👤 Stored fallback username: \(userName)")
                }
                
                // Store token if available
                if let token = response.token {
                    UserDefaults.standard.set(token, forKey: "authToken")
                    print("💾 Token saved: \(token.prefix(20))...")
                }
            }
            .store(in: &cancellables)
    }
    func logout() {
        print("🚪 Logging out user: \(currentUser ?? "unknown")")
        
        // Clear authentication state
        isAuthenticated = false
        currentUser = nil
        UserDefaults.standard.removeObject(forKey: "authToken")
        UserDefaults.standard.removeObject(forKey: "currentUsername")
        
        // Clear any error messages
        errorMessage = nil
        
        print("✅ User logged out successfully")
    }
    
    // Check if user is already authenticated (on app start)
    func checkAuthenticationStatus() {
        if let token = UserDefaults.standard.string(forKey: "authToken"), !token.isEmpty {
            if let username = UserDefaults.standard.string(forKey: "currentUsername") {
                isAuthenticated = true
                currentUser = username
                print("🔑 Found existing token and username, user is authenticated: \(username)")
                print("🔑 Found existing token and username, user is authenticated: \(token)")
                
            } else {
                isAuthenticated = false
                print("🔐 Token found but no username, requiring login")
            }
        } else {
            isAuthenticated = false
            print("🔐 No token found, user needs to login")
        }
    }
    func register(userName: String, email: String, displayName: String, phoneNumber: String, password: String, profilePicture: Data?) {
        isLoading = true
        errorMessage = nil
        
        let request = RegisterRequest(
            userName: userName,
            email: email,
            displayName: displayName,
            phoneNumber: phoneNumber,
            password: password,
            profilePicture: profilePicture
        )
        
        AuthnticationServices.shared.register(request)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                    print("Registration error: \(error)")
                }
            } receiveValue: { [weak self] message in
                print("Registration successful: \(message)")
                // Auto login after registration
                self?.login(userName: userName, password: password)
            }
            .store(in: &cancellables)
    }
}
