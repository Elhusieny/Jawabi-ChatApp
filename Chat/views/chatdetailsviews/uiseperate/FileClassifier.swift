import Foundation

/// Pure, stateless logic for classifying files by extension.
/// Single responsibility: "what kind of file is this, and what's its mime type".
final class FileClassifier: FileClassifying {

    private let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "gif", "webp", "bmp", "tiff"]
    private let audioExtensions: Set<String> = ["m4a", "mp3", "wav", "aac", "ogg", "caf", "aiff"]

    func mimeType(for fileName: String) -> String {
        switch extensionOf(fileName) {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "pdf": return "application/pdf"
        case "doc", "docx": return "application/msword"
        case "txt": return "text/plain"
        case "zip", "rar": return "application/zip"
        case "m4a", "mp3", "aac", "wav": return "audio/mpeg"
        default: return "application/octet-stream"
        }
    }

    func isImage(fileName: String) -> Bool {
        imageExtensions.contains(extensionOf(fileName))
    }

    func isAudio(fileName: String) -> Bool {
        audioExtensions.contains(extensionOf(fileName))
    }

    private func extensionOf(_ fileName: String) -> String {
        (fileName as NSString).pathExtension.lowercased()
    }
}