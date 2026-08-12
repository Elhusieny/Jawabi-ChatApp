import Foundation

/// Single responsibility: given an already-uploaded file, tell SignalR
/// about it as either a group or private message, as voice or file type.
/// Doesn't know how the upload happened or how to render bubbles.
final class FileMessageSender: FileMessageSending {

    private let signalRProvider: () -> SignalRService?

    init(signalRProvider: @escaping () -> SignalRService?) {
        self.signalRProvider = signalRProvider
    }

    func send(result: FileUploadResult, chatId: Int, isGroup: Bool) {
        guard let signalR = signalRProvider() else { return }
        let type: MessageType = result.isVoice ? .voice : .file

        if isGroup {
            signalR.sendGroupMessage(
                result.fileUrl,
                chatId: chatId,
                fileUrl: result.fileUrl,
                fileName: result.fileName,
                fileSize: result.fileSize,
                fileExtension: result.fileExtension,
                type: type
            )
        } else {
            signalR.sendMessage(
                result.fileUrl,
                chatId: chatId,
                fileUrl: result.fileUrl,
                fileName: result.fileName,
                fileSize: result.fileSize,
                fileExtension: result.fileExtension,
                type: type
            )
        }
    }
}