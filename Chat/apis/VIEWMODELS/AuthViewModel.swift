import Foundation
import Combine
import SwiftUI

class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentUser: String?
    @Published var showAlert = false
    @Published var alertMessage = ""
    
    // Add UserInfo model
    struct UserInfo: Codable {
        let userName: String?
        let email: String?
        let displayName: String?
        let phoneNumber: String?
        let profilePicture: String?
    }
    
    @Published var userInfo: UserInfo?
    
    private var cancellables = Set<AnyCancellable>()
    private let authService = AuthnticationServices.shared
    private let deleteAccountService = DeleteAccountService.shared
    
    init() {
        checkAuthentication()
    }
    
    // MARK: - Delete Account
    func deleteAccount() {
        isLoading = true
        errorMessage = nil
        
        print("🗑️ Starting account deletion process...")
        
        deleteAccountService.deleteAccount()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                switch completion {
                case .failure(let error):
                    let errorMessage = "Failed to delete account: \(error.localizedDescription)"
                    self?.errorMessage = errorMessage
                    self?.showAlert = true
                    self?.alertMessage = errorMessage
                    print("❌ Error deleting account: \(error)")
                case .finished:
                    print("✅ Account deletion process completed")
                }
            } receiveValue: { [weak self] success in
                if success {
                    print("✅ Account deleted successfully - clearing local data")
                    
                    // Clear all user data
                    self?.clearAllUserData()
                    
                    // Update auth state
                    self?.isAuthenticated = false
                    self?.currentUser = nil
                    self?.userInfo = nil
                    
                    // Show success message
                    self?.showAlert = true
                    self?.alertMessage = "Account deleted successfully"
                }
            }
            .store(in: &cancellables)
    }
    
    private func clearAllUserData() {
        print("🧹 Clearing all user data...")
        
        // Clear UserDefaults
        let keysToRemove = [
            "authToken", "currentUsername", "userDisplayName",
            "userName", "currentUserId", "userId", "userEmail",
            "userPhoneNumber", "userProfilePicture"
        ]
        
        for key in keysToRemove {
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        // Clear chat data by removing all keys that start with "chats_"
        let allKeys = UserDefaults.standard.dictionaryRepresentation().keys
        for key in allKeys {
            if key.hasPrefix("chats_") {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        
        UserDefaults.standard.synchronize()
        print("✅ All user data cleared")
    }
    
    // MARK: - Load User Info
    func loadUserInfo() {
        print("👤 Loading user info from UserDefaults...")
        
        let userName = UserDefaults.standard.string(forKey: "currentUsername") ??
                      UserDefaults.standard.string(forKey: "userName")
        let email = UserDefaults.standard.string(forKey: "userEmail")
        let displayName = UserDefaults.standard.string(forKey: "userDisplayName")
        let phoneNumber = UserDefaults.standard.string(forKey: "userPhoneNumber")
        let profilePicture = UserDefaults.standard.string(forKey: "userProfilePicture")
        
        userInfo = UserInfo(
            userName: userName,
            email: email,
            displayName: displayName,
            phoneNumber: phoneNumber,
            profilePicture: profilePicture
        )
        
        currentUser = displayName ?? userName ?? "User"
        
        print("✅ Loaded user info:")
        print("   Name: \(userName ?? "N/A")")
        print("   Display Name: \(displayName ?? "N/A")")
        print("   Email: \(email ?? "N/A")")
        print("   Phone: \(phoneNumber ?? "N/A")")
    }
    
    // MARK: - Authentication Methods
    func login(userName: String, password: String) {
        isLoading = true
        errorMessage = nil
        
        print("🔐 Attempting login for: \(userName)")
        
        authService.login(userName: userName, password: password)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                switch completion {
                case .failure(let error):
                    let errorMessage = "Login failed: \(error.localizedDescription)"
                    self?.errorMessage = errorMessage
                    self?.isAuthenticated = false
                    print("❌ Login error: \(errorMessage)")
                    
                    // Clear any invalid tokens
                    UserDefaults.standard.removeObject(forKey: "authToken")
                    
                case .finished:
                    print("✅ Login completed successfully")
                }
            } receiveValue: { [weak self] response in
                print("✅ Login successful for: \(response.userName ?? "unknown")")
                self?.handleSuccessfulLogin(response: response, userName: userName)
            }
            .store(in: &cancellables)
    }
    func checkAuthenticationStatus() {
        if let token = UserDefaults.standard.string(forKey: "authToken"), !token.isEmpty {
            if let username = UserDefaults.standard.string(forKey: "currentUsername") {
                isAuthenticated = true
                currentUser = username
                print("🔑 Found existing token and username, user is authenticated: \(username)")
                print("🔑 Token exists and is non-empty")
                
                // Notify that we have valid authentication
                NotificationCenter.default.post(
                    name: NSNotification.Name("UserDidLogin"),
                    object: nil
                )
            } else {
                isAuthenticated = false
                print("🔐 Token found but no username, requiring login")
            }
        } else {
            isAuthenticated = false
            print("🔐 No valid token found, user needs to login")
        }
    }

    
    private func handleSuccessfulLogin(response: LoginResponse, userName: String) {
        self.isAuthenticated = true
        
        // Store user information
        if let userName = response.userName {
            self.currentUser = userName
            UserDefaults.standard.set(userName, forKey: "currentUsername")
            UserDefaults.standard.set(userName, forKey: "userName")
            print("👤 Stored username: \(userName)")
        } else {
            // Fallback to the entered username
            self.currentUser = userName
            UserDefaults.standard.set(userName, forKey: "currentUsername")
            UserDefaults.standard.set(userName, forKey: "userName")
            print("👤 Stored fallback username: \(userName)")
        }
        
        // Store other user info
        if let displayName = response.displayName {
            UserDefaults.standard.set(displayName, forKey: "userDisplayName")
            self.currentUser = displayName // Prefer display name for UI
        }
        
        if let email = response.email {
            UserDefaults.standard.set(email, forKey: "userEmail")
        }
        
        // Store token
        if let token = response.token {
            UserDefaults.standard.set(token, forKey: "authToken")
            print("💾 Token saved successfully")
            print("🔑 Token preview: \(token.prefix(20))...")
            
            // Load user info after login
            self.loadUserInfo()
            
            // Notify that authentication changed (for SignalR to reconnect)
            NotificationCenter.default.post(
                name: NSNotification.Name("UserDidLogin"),
                object: nil
            )
        } else {
            print("⚠️ No token received in login response")
        }
    }
    
    func logout() {
        print("🚪 Logging out user: \(currentUser ?? "unknown")")
        
        // Clear all authentication data
        clearAllUserData()
        isAuthenticated = false
        currentUser = nil
        userInfo = nil
        errorMessage = nil
        
        // Notify that user logged out
        NotificationCenter.default.post(
            name: NSNotification.Name("UserDidLogout"),
            object: nil
        )
        
        print("✅ User logged out successfully")
    }
    
    func checkAuthentication() {
        if let token = UserDefaults.standard.string(forKey: "authToken"), !token.isEmpty {
            if let username = UserDefaults.standard.string(forKey: "currentUsername") {
                isAuthenticated = true
                currentUser = username
                loadUserInfo() // Load user info when checking authentication
                print("🔑 Found existing token and username, user is authenticated: \(username)")
                
                // Notify that we have valid authentication
                NotificationCenter.default.post(
                    name: NSNotification.Name("UserDidLogin"),
                    object: nil
                )
            } else {
                isAuthenticated = false
                print("🔐 Token found but no username, requiring login")
            }
        } else {
            isAuthenticated = false
            print("🔐 No valid token found, user needs to login")
        }
    }
    
    // MARK: - Registration
    func register(userName: String, email: String, displayName: String, phoneNumber: String, password: String, profilePicture: Data?, serverUrl: String?) {
        isLoading = true
        errorMessage = nil
        
        let request = RegisterRequest(
            userName: userName,
            email: email,
            displayName: displayName,
            phoneNumber: phoneNumber,
            password: password,
            profilePicture: profilePicture,
            serverUrl: serverUrl
        )
        
        authService.register(request)
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
