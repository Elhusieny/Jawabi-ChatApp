import Foundation

/// Coordinates the "send an attachment" use case by composing the
/// single-purpose services above. It has one responsibility of its
/// own: sequencing (placeholder -> upload -> update -> dispatch),
/// not the mechanics of any individual step.
final class AttachmentSendingCoordinator {

    private let uploadService: FileUploadServicing
    private let messageSender: FileMessageSending
    private let temporaryMessages: TemporaryMessageManaging
    private let currentUserProvider: CurrentUserProviding
    private let alertPresenter: AlertPresenting

    init(
        uploadService: FileUploadServicing,
        messageSender: FileMessageSending,
        temporaryMessages: TemporaryMessageManaging,
        currentUserProvider: CurrentUserProviding,
        alertPresenter: AlertPresenting
    ) {
        self.uploadService = uploadService
        self.messageSender = messageSender
        self.temporaryMessages = temporaryMessages
        self.currentUserProvider = currentUserProvider
        self.alertPresenter = alertPresenter
    }

    /// - Parameter onFinished: called on the main queue once the upload
    ///   attempt is fully resolved (success or failure), so the view can
    ///   clear its "uploading" spinner / selection state.
    func sendAttachment(
        data: Data,
        fileName: String,
        chatId: Int,
        isGroup: Bool,
        onFinished: @escaping () -> Void
    ) {
        let tempMessageId = -Int.random(in: 1_000_000...9_999_999)
        let tempMessage = Message(
            id: tempMessageId,
            displayText: "SCANNING:\(fileName)",
            name: currentUserProvider.currentUsername(),
            timestamp: ISO8601DateFormatter.shared.string(from: Date()),
            isRead: false
        )
        temporaryMessages.addTemporaryMessage(tempMessage, chatId: chatId)
        temporaryMessages.updateTemporaryMessage(tempMessageId, chatId: chatId, displayText: "UPLOADING:\(fileName)")

        uploadService.uploadFile(data: data, fileName: fileName) { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                switch result {
                case .success(let uploadResult):
                    self.handleSuccess(uploadResult, tempMessageId: tempMessageId, chatId: chatId, isGroup: isGroup)
                case .failure(let error):
                    self.handleFailure(error, tempMessageId: tempMessageId, chatId: chatId, fileName: fileName)
                }
                onFinished()
            }
        }
    }

    private func handleSuccess(_ result: FileUploadResult, tempMessageId: Int, chatId: Int, isGroup: Bool) {
        if result.isVoice {
            temporaryMessages.updateTemporaryMessage(tempMessageId, chatId: chatId, displayText: result.fileUrl)
        } else {
            temporaryMessages.updateTemporaryMessage(tempMessageId, chatId: chatId, displayText: "SCANNING:\(result.fileName)")
        }
        messageSender.send(result: result, chatId: chatId, isGroup: isGroup)
    }

    private func handleFailure(_ error: Error, tempMessageId: Int, chatId: Int, fileName: String) {
        if case FileUploadError.blocked = error {
            temporaryMessages.removeTemporaryMessage(tempMessageId, chatId: chatId)
            alertPresenter.showAlert(title: "File Blocked", message: error.localizedDescription)
        } else {
            temporaryMessages.updateTemporaryMessage(
                tempMessageId,
                chatId: chatId,
                displayText: "❌ Upload failed: \(error.localizedDescription)"
            )
            alertPresenter.showAlert(title: "Upload Failed", message: "Upload failed: \(error.localizedDescription)")
        }
    }
}