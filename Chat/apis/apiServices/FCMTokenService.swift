import Foundation
import UIKit

class FCMTokenService {
    static let shared = FCMTokenService()
    private init() {}
    
    func sendTokenToBackend(_ fcmToken: String) {
        guard let authToken = UserDefaults.standard.string(forKey: "authToken"),
              !authToken.isEmpty else {
            print("⚠️ No auth token yet — saving FCM token for later")
            UserDefaults.standard.set(fcmToken, forKey: "pendingFcmToken")
            return
        }
        
        guard let url = URL(string: "http://158.220.90.131:8444/api/Chat/update-device-token") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        // ✅ Use "token" as the key (not "fcmToken")
        let body: [String: String] = [
            "token": fcmToken
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        print("📤 Sending FCM token as JSON")
        print("   Body: {\"token\": \"\(fcmToken.prefix(30))...\"}")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Network error: \(error.localizedDescription)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 FCM token response status: \(httpResponse.statusCode)")
                
                if let data = data, let body = String(data: data, encoding: .utf8) {
                    print("📦 FCM response body: \(body)")
                }
                
                if httpResponse.statusCode == 200 {
                    print("✅ FCM token successfully registered with backend")
                } else {
                    print("⚠️ Failed to register FCM token - status: \(httpResponse.statusCode)")
                }
            }
        }.resume()
    }
    
    func sendPendingTokenIfNeeded() {
        if let pending = UserDefaults.standard.string(forKey: "pendingFcmToken") {
            print("📤 Sending pending FCM token after login...")
            sendTokenToBackend(pending)
            UserDefaults.standard.removeObject(forKey: "pendingFcmToken")
        }
    }
}

