import Foundation
import UIKit

// MARK: - File Upload Result

struct FileUploadResult {
    let fileUrl: String
    let fileName: String
    let fileExtension: String
    let fileSize: Int64
    let isVoice: Bool
    let isSafe: Bool
}

// MARK: - 1. Uploading files (network call + multipart body + response parsing)

protocol FileUploadServicing {
    func uploadFile(
        data: Data,
        fileName: String,
        completion: @escaping (Result<FileUploadResult, Error>) -> Void
    )
}

// MARK: - 2. Sending the uploaded/recorded file over SignalR

protocol FileMessageSending {
    func send(
        result: FileUploadResult,
        chatId: Int,
        isGroup: Bool
    )
}

// MARK: - 3. Managing the temporary/placeholder message lifecycle
// (the "SCANNING:", "UPLOADING:", error-state bubble that gets swapped
// out once the real upload finishes)

protocol TemporaryMessageManaging {
    func addTemporaryMessage(_ message: Message, chatId: Int)
    func updateTemporaryMessage(_ tempMessageId: Int, chatId: Int, displayText: String)
    func removeTemporaryMessage(_ tempMessageId: Int, chatId: Int)
}

// MARK: - 4. Knowing who "the current user" is, and whether a message belongs to them

protocol CurrentUserProviding {
    func currentUsername() -> String
    func isCurrentUser(message: Message) -> Bool
}

// MARK: - 5. Network reachability monitoring

protocol NetworkMonitoring: AnyObject {
    func startMonitoring(onStatusChange: @escaping (_ isOffline: Bool) -> Void)
    func stopMonitoring()
}

// MARK: - 6. Persisting messages composed while offline

protocol OfflineMessageStoring {
    func saveOfflineMessage(_ text: String, chatId: Int)
}

// MARK: - 7. Presenting alerts / confirmations (UIKit-bridge concern)

protocol AlertPresenting {
    func showAlert(title: String, message: String)
    func showConfirmation(
        title: String,
        message: String,
        confirmTitle: String,
        isDestructive: Bool,
        onConfirm: @escaping () -> Void
    )
}

// MARK: - 8. Deciding mime types / file classification (small pure-logic helper)

protocol FileClassifying {
    func mimeType(for fileName: String) -> String
    func isImage(fileName: String) -> Bool
    func isAudio(fileName: String) -> Bool
}