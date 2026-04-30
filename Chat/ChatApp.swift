
// App.swift or your main app file
import SwiftUI
import UserNotifications
import FirebaseCore
import FirebaseMessaging  // ADD THIS

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        print("🔥 Firebase configured")
        
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        print("📋 Delegates set")
        
        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("✅ APNs token received: \(tokenString.prefix(20))...")
        print("📤 Forwarding APNs token to Firebase...")
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ FAILED to register for remote notifications: \(error.localizedDescription)")
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("📱 FCM delegate called")
        guard let token = fcmToken else {
            print("❌ FCM token is nil")
            return
        }
        print("📱 FCM Token: \(token)")
        UserDefaults.standard.set(token, forKey: "fcmToken")
        FCMTokenService.shared.sendTokenToBackend(token)
    }
    

    // MARK: - UNUserNotificationCenterDelegate
    // Show notification even when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("📲 Notification tapped: \(userInfo)")
        completionHandler()
    }
}

@main
struct ChatApp: App {
    
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var chatViewModel = ChatViewModel()
    // In your root ContentView or App struct
    @State private var showingAddAccount = false
    // register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isAuthenticated {
                    ChatListView()
                        .environmentObject(authViewModel)
                        .environmentObject(chatViewModel)
                } else {
                    LoginView()
                        .environmentObject(authViewModel)
                }
            }
            .onAppear {
                authViewModel.checkAuthenticationStatus()
                authViewModel.loadSavedAccounts()
                requestNotificationPermissions() // ADD THIS
                
                
            }
            // Inside .onReceive or .onAppear
            .onReceive(NotificationCenter.default.publisher(
                for: NSNotification.Name("AddNewAccount")
            )) { _ in
                showingAddAccount = true
            }
            .sheet(isPresented: $showingAddAccount) {
                LoginView()
                    .environmentObject(authViewModel)
            }
            
        }
    }
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            print("🔔 Permission granted: \(granted), error: \(String(describing: error))")
            
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                    print("📡 registerForRemoteNotifications called")
                    
                    // ✅ Also force-fetch FCM token directly
                    Messaging.messaging().token { token, error in
                        if let error = error {
                            print("❌ FCM token fetch error: \(error.localizedDescription)")
                        } else if let token = token {
                            print("📱 FCM Token (manual fetch): \(token)")
                            UserDefaults.standard.set(token, forKey: "fcmToken")
                            FCMTokenService.shared.sendTokenToBackend(token)
                        }
                    }
                }
            }
        }
    }
}
