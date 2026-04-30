import Foundation
import Combine
import SwiftUI

/// ViewModel responsible for managing authentication state and user account operations
class AuthViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// Indicates whether the user is currently authenticated
    @Published var isAuthenticated = false
    
    /// Indicates if any authentication operation is in progress
    @Published var isLoading = false
    
    /// Stores any error message that occurred during authentication
    @Published var errorMessage: String?
    
    /// The currently authenticated user's display name or username
    @Published var currentUser: String?
    
    /// Controls whether to show an alert dialog
    @Published var showAlert = false
    
    /// The message to display in the alert dialog
    @Published var alertMessage = ""
    
    /// List of saved usernames from Keychain for quick login
    @Published var savedAccounts: [String] = []
    
    /// Controls whether to show the saved accounts selection view
    @Published var shouldShowSavedAccounts = false
    
    /// User information model containing profile details
    struct UserInfo: Codable {
        let userName: String?
        let email: String?
        let displayName: String?
        let phoneNumber: String?
        var profilePicture: String?
    }
    
    /// The current user's profile information
    @Published var userInfo: UserInfo?
    
    /// Set of Combine cancellables for managing subscriptions
    var cancellables = Set<AnyCancellable>()
    
    /// Authentication service instance
    private let authService = AuthenticationServices.shared
    
    /// Account deletion service instance
    private let deleteAccountService = DeleteAccountService.shared
    
    // MARK: - Initialization
    
    init() {
        checkAuthentication()
    }
    
    // MARK: - Account Deletion
    
    /// Deletes the current user's account permanently
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
    
    /// Clears all user data from UserDefaults
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
    
    // MARK: - User Info Management
    
    /// Loads user information from UserDefaults
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
    
    /// Authenticates a user with username and password
    /// - Parameters:
    ///   - userName: The username to log in with
    ///   - password: The password to log in with
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
                self?.handleSuccessfulLogin(response: response, userName: userName, password: password)
            }
            .store(in: &cancellables)
    }
    
    /// Checks the current authentication status from stored tokens
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
    
    /// Handles successful login response by saving user data
    /// - Parameters:
    ///   - response: The login response from the server
    ///   - userName: The username used for login
    ///   - password: The password used for login
    private func handleSuccessfulLogin(response: LoginResponse, userName: String, password: String) {
        self.isAuthenticated = true
        
        // Store user information
        if let userName = response.userName {
            self.currentUser = userName
            UserDefaults.standard.set(userName, forKey: "currentUsername")
            UserDefaults.standard.set(userName, forKey: "userName")
            
            // Save credentials to Keychain
            KeychainManager.shared.saveCredentials(username: userName, password: password)
            print("💾 Credentials saved for: \(userName)")
        } else {
            // Fallback to the entered username
            self.currentUser = userName
            UserDefaults.standard.set(userName, forKey: "currentUsername")
            UserDefaults.standard.set(userName, forKey: "userName")
            
            // Save credentials to Keychain
            KeychainManager.shared.saveCredentials(username: userName, password: password)
            print("💾 Credentials saved (fallback) for: \(userName)")
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
            // ✅ ADD THIS — send any pending FCM token now that we're authenticated
                   FCMTokenService.shared.sendPendingTokenIfNeeded()
                   //print(" ffff \(FCMTokenService.shared.sendPendingTokenIfNeeded()")
                   NotificationCenter.default.post(
                       name: NSNotification.Name("UserDidLogin"),
                       object: nil
                   )
            // Notify that authentication changed (for SignalR to reconnect)
            NotificationCenter.default.post(
                name: NSNotification.Name("UserDidLogin"),
                object: nil
            )
        } else {
            print("⚠️ No token received in login response")
        }
    }
    
    /// Logs out the current user and clears session data
    func logout() {
        print("🚪 Logging out user: \(currentUser ?? "unknown")")
        
        // Clear all authentication data
        // Only clear session data
        clearSessionData()
        // Show saved accounts after logout
        shouldShowSavedAccounts = true
        // Notify that user logged out
        loadSavedAccounts()
        
        print("✅ User logged out successfully")
    }
    
    /// Clears session-specific data while preserving saved credentials
    private func clearSessionData() {
        // Clear session-specific data but NOT saved credentials
        UserDefaults.standard.removeObject(forKey: "authToken")
        UserDefaults.standard.removeObject(forKey: "currentUsername")
        UserDefaults.standard.removeObject(forKey: "userDisplayName")
        
        isAuthenticated = false
        currentUser = nil
        userInfo = nil
        errorMessage = nil
    }
    
    /// Loads saved accounts from Keychain
    func loadSavedAccounts() {
        savedAccounts = KeychainManager.shared.getAllSavedUsernames()
        print("📋 Loaded saved accounts: \(savedAccounts)")
    }
    
    /// Retrieves credentials for a saved account
    /// - Parameter username: The username to get credentials for
    /// - Returns: Tuple containing username and password if found, nil otherwise
    func autoFillCredentials(for username: String) -> (username: String, password: String)? {
        if let password = KeychainManager.shared.getCredentials(for: username) {
            return (username, password)
        }
        return nil
    }
    
    /// Deletes a saved account from Keychain
    /// - Parameter username: The username to delete
    func deleteSavedAccount(_ username: String) {
        KeychainManager.shared.deleteCredentials(for: username)
        loadSavedAccounts() // Refresh the list
    }
    
    /// Checks authentication status on app start
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
    // Add this method to AuthViewModel
    func switchAccount(to username: String) {
        guard let credentials = autoFillCredentials(for: username) else {
            errorMessage = "Could not retrieve credentials for \(username)"
            return
        }
        
        // Save current username before clearing session
        let previousUsername = currentUser
        print("🔄 Switching from \(previousUsername ?? "unknown") to \(username)")
        
        // Clear current session (but NOT keychain — we need all saved passwords)
        clearSessionData()
        
        // Login to the new account
        login(userName: credentials.username, password: credentials.password)
    }
}
