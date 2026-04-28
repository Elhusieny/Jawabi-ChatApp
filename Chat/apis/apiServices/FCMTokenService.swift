import Foundation

class FCMTokenService {
    static let shared = FCMTokenService()
    private init() {}
    
    /// Call this after login, or whenever FCM token refreshes
    func sendTokenToBackend(_ token: String) {
        guard let authToken = UserDefaults.standard.string(forKey: "authToken"),
              !authToken.isEmpty else {
            print("⚠️ No auth token yet — FCM token will be sent after login")
            // Save it and send later when user logs in
            UserDefaults.standard.set(token, forKey: "pendingFcmToken")
            return
        }
        
        guard let url = URL(string: "https://YOUR_BACKEND_URL/api/notifications/register-token") else {
            print("❌ Invalid backend URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        let body: [String: String] = [
            "fcmToken": token,
            "platform": "iOS",
            "deviceId": UIDevice.current.identifierForVendor?.uuidString ?? ""
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Failed to send FCM token: \(error)")
                return
            }
            if let httpResponse = response as? HTTPURLResponse {
                print("✅ FCM token sent — status: \(httpResponse.statusCode)")
            }
        }.resume()
    }
    
    /// Call this right after successful login
    func sendPendingTokenIfNeeded() {
        if let pendingToken = UserDefaults.standard.string(forKey: "pendingFcmToken") {
            print("📤 Sending pending FCM token after login...")
            sendTokenToBackend(pendingToken)
            UserDefaults.standard.removeObject(forKey: "pendingFcmToken")
        }
    }
}