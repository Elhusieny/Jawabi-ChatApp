
//import Foundation
//import Combine
//
//class DeleteAccountVM{
//    private let deleteAccountService = DeleteAccountService.shared
//    @Published var isAuthenticated = false
//       @Published var currentUser: String?
//       @Published var isLoading = false
//       @Published var errorMessage: String?
//       @Published var showAlert = false
//       @Published var alertMessage = ""
//       private var cancellables = Set<AnyCancellable>()
//       private let authService = AuthService.shared
//    // MARK: - Delete Account
//    func deleteAccount() {
//        isLoading = true
//        errorMessage = nil
//        print("🗑️ Starting account deletion process...")
//        
//        deleteAccountService.deleteAccount()
//            .receive(on: DispatchQueue.main)
//            .sink { [weak self] completion in
//                self?.isLoading = false
//                switch completion {
//                case .failure(let error):
//                    self?.errorMessage = "Failed to delete account: \(error.localizedDescription)"
//                    self?.showAlert = true
//                    self?.alertMessage = "Failed to delete account: \(error.localizedDescription)"
//                    print("❌ Error deleting account: \(error)")
//                case .finished:
//                    print("✅ Account deletion process completed")
//                }
//            } receiveValue: { [weak self] success in
//                if success {
//                    print("✅ Account deleted successfully - clearing local data")
//                    
//                    // Clear all user data
//                    self?.clearAllUserData()
//                    
//                    // Update auth state
//                    self?.isAuthenticated = false
//                    self?.currentUser = nil
//                    self?.userInfo = nil
//                    
//                    // Show success message
//                    self?.showAlert = true
//                    self?.alertMessage = "Account deleted successfully"
//                }
//            }
//            .store(in: &cancellables)
//    }
//    
//    private func clearAllUserData() {
//        print("🧹 Clearing all user data...")
//        
//        // Clear UserDefaults
//        let keysToRemove = [
//            "authToken", "currentUsername", "userDisplayName",
//            "userName", "currentUserId", "userId", "userEmail",
//            "userPhoneNumber", "userProfilePicture"
//        ]
//        
//        for key in keysToRemove {
//            UserDefaults.standard.removeObject(forKey: key)
//        }
//        
//        // Clear chat data by removing all keys that start with "chats_"
//        let allKeys = UserDefaults.standard.dictionaryRepresentation().keys
//        for key in allKeys {
//            if key.hasPrefix("chats_") {
//                UserDefaults.standard.removeObject(forKey: key)
//            }
//        }
//        
//        UserDefaults.standard.synchronize()
//        print("✅ All user data cleared")
//    }
//    
//    // MARK: - Load User Info
//    func loadUserInfo() {
//        print("👤 Loading user info from UserDefaults...")
//        
//        let userName = UserDefaults.standard.string(forKey: "currentUsername") ??
//        UserDefaults.standard.string(forKey: "userName")
//        let email = UserDefaults.standard.string(forKey: "userEmail")
//        let displayName = UserDefaults.standard.string(forKey: "userDisplayName")
//        let phoneNumber = UserDefaults.standard.string(forKey: "userPhoneNumber")
//        let profilePicture = UserDefaults.standard.string(forKey: "userProfilePicture")
//        
//        userInfo = UserInfo(
//            userName: userName,
//            email: email,
//            displayName: displayName,
//            phoneNumber: phoneNumber,
//            profilePicture: profilePicture
//        )
//        
//        currentUser = displayName ?? userName ?? "User"
//        
//        print("✅ Loaded user info:")
//        print("   Name: \(userName ?? "N/A")")
//        print("   Display Name: \(displayName ?? "N/A")")
//        print("   Email: \(email ?? "N/A")")
//        print("   Phone: \(phoneNumber ?? "N/A")")
//    }
//    
//    // Rest of your existing AuthViewModel methods...
//    func checkAuthentication() {
//        if let token = UserDefaults.standard.string(forKey: "authToken"), !token.isEmpty {
//            isAuthenticated = true
//            loadUserInfo()
//            print("✅ User authenticated with token")
//        } else {
//            isAuthenticated = false
//            print("❌ No authentication token found")
//        }
//    }
//    
//    func login(username: String, password: String) {
//        // Your existing login implementation
//    }
//    
//    func logout() {
//        // Your existing logout implementation
//        clearAllUserData()
//        isAuthenticated = false
//        currentUser = nil
//        userInfo = nil
//        print("🚪 User logged out")
//    }
//    
//}
