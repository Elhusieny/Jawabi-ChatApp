import Foundation

/// Single responsibility: persist the username for quick relogin, then
/// sign out. Kept separate so the confirmation dialog in the view is
/// pure UI, and this logic is reusable/testable without SwiftUI.
final class LogoutCoordinator: AuthSessionLogoutHandling {

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func logout(currentUsername: String?, authViewModel: AuthViewModel) {
        if let currentUsername = currentUsername {
            userDefaults.set(currentUsername, forKey: "lastUsername")
        }
        authViewModel.logout()
    }
}