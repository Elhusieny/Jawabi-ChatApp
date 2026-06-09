
import SwiftUI
import UserNotifications
import FirebaseCore
import FirebaseMessaging
 
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    
    // ✅ Store the chat ID from Firebase notification
    static var chatIdFromLaunchNotification: Int?
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        print("🔥 Firebase configured")
        
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        print("📋 Delegates set")
        
        // Note: We can't reliably get notification in launchOptions due to Firebase swizzling
        // Firebase will handle it via the UNUserNotificationCenterDelegate instead
        
        return true
    }
    
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("✅ APNs token received: \(tokenString.prefix(20))...")
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
    
    // In AppDelegate.swift
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("📲📲📲 NOTIFICATION TAPPED (didReceive called)")
        
        // Extract chatId
        var chatIdInt: Int?
        
        if let chatId = userInfo["chatId"] as? String, let id = Int(chatId) {
            chatIdInt = id
        } else if let id = userInfo["chatId"] as? Int {
            chatIdInt = id
        } else if let chatId = userInfo["chat_id"] as? String, let id = Int(chatId) {
            chatIdInt = id
        }
        
        guard let chatId = chatIdInt else {
            completionHandler()
            return
        }
        
        print("🎯 Extracted chatId: \(chatId)")
        
        // IMPORTANT: Post notification on main thread with delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("📤 Posting NavigateToChatDetail notification")
            NotificationCenter.default.post(
                name: NSNotification.Name("NavigateToChatDetail"),
                object: nil,
                userInfo: ["chatId": chatId, "fromNotification": true]
            )
        }
        
        completionHandler()
    }
}
 
@main
struct ChatApp: App {
    
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var chatViewModel = ChatViewModel()
    @State private var showingAddAccount = false
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var hasProcessedLaunchNotification = false
 
    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isAuthenticated {
                    ChatListView()
                        .environmentObject(authViewModel)
                        .environmentObject(chatViewModel)
                        // ✅ When ChatListView appears, process stored notification
                        .onAppear {
                            print("🎯🎯🎯 ChatListView onAppear")
                            
                            if !hasProcessedLaunchNotification,
                               let chatIdFromLaunch = AppDelegate.chatIdFromLaunchNotification {
                                print("🚀 Processing stored launch notification")
                                print("   Chat ID: \(chatIdFromLaunch)")
                                
                                // Wait for chats to load, then navigate
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    print("🎯 Posting NavigateToChatDetail from stored notification")
                                    NotificationCenter.default.post(
                                        name: NSNotification.Name("NavigateToChatDetail"),
                                        object: nil,
                                        userInfo: ["chatId": chatIdFromLaunch]
                                    )
                                    hasProcessedLaunchNotification = true
                                    AppDelegate.chatIdFromLaunchNotification = nil
                                }
                            }
                        }
                } else {
                    LoginView()
                        .environmentObject(authViewModel)
                }
            }
            .onAppear {
                print("🔐 App onAppear")
                authViewModel.checkAuthenticationStatus()
                authViewModel.loadSavedAccounts()
                requestNotificationPermissions()
            }
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
            print("🔔 Permission granted: \(granted)")
            
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                    print("📡 registerForRemoteNotifications called")
                    
                    Messaging.messaging().token { token, error in
                        if let error = error {
                            print("❌ FCM token error: \(error)")
                        } else if let token = token {
                            print("📱 FCM Token obtained")
                            UserDefaults.standard.set(token, forKey: "fcmToken")
                            FCMTokenService.shared.sendTokenToBackend(token)
                        }
                    }
                }
            }
        }
    }
}
