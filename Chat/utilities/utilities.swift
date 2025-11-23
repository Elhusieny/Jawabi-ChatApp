
import Foundation
import UIKit
class Utilities {
    static let baseURL = "http://158.220.90.131:8444"
}
enum NetworkError: Error {
    case invalidURL
    case invalidResponse
    case decodingError
    case serverError(String)
}
// Add this extension for better date formatting
extension Date {
    func formattedTime() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
}



// For handling image uploads
extension UIImage {
    func toData() -> Data? {
        return self.jpegData(compressionQuality: 0.8)
    }
}
