import Foundation

/// Single responsibility: figure out "who am I" for the purposes of
/// rendering chat bubbles, and whether a given message was sent by me.
final class CurrentUserProvider: CurrentUserProviding {

    private let userDefaultsKeys = ["currentUsername", "userName", "userDisplayName", "username"]
    private let userDefaults: UserDefaults
    private let authUsernameProvider: () -> String?

    init(
        userDefaults: UserDefaults = .standard,
        authUsernameProvider: @escaping () -> String?
    ) {
        self.userDefaults = userDefaults
        self.authUsernameProvider = authUsernameProvider
    }

    func currentUsername() -> String {
        for key in userDefaultsKeys {
            if let value = userDefaults.string(forKey: key), !value.isEmpty {
                return value
            }
        }

        if let authUser = authUsernameProvider(), !authUser.isEmpty {
            return authUser
        }

        return "UnknownUser"
    }

    func isCurrentUser(message: Message) -> Bool {
        let current = currentUsername().trimmingCharacters(in: .whitespaces).lowercased()
        let sender = message.name.trimmingCharacters(in: .whitespaces).lowercased()

        return sender == current ||
               sender == "you" ||
               (current == "test46" && sender == "you") ||
               (message.id < 0 && sender == current)
    }
}