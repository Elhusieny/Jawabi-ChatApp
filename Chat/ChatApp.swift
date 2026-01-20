
// App.swift or your main app file

import SwiftUI
import UserNotifications // ADD THIS IMPORT

@main
struct ChatApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var chatViewModel = ChatViewModel()
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
                requestNotificationPermissions() // ADD THIS
                
//                // Auto-connect SignalR when app launches with better timing
//                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
//                    chatViewModel.connectSignalR()
//                }
            }
//            .onChange(of: scenePhase) { newPhase in
//                switch newPhase {
//                case .active:
//                    print("📱 App became active - ensuring SignalR connection")
//                    chatViewModel.ensureSignalRConnection()
//                case .background:
//                    print("📱 App went to background")
//                case .inactive:
//                    print("📱 App became inactive")
//                @unknown default:
//                    break
//                }
//            }
        }
    }
    
    // ADD THIS METHOD
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ Notification permissions granted")
            } else if let error = error {
                print("❌ Notification permissions error: \(error)")
            } else {
                print("❌ Notification permissions denied")
            }
        }
    }
}
    // In your App.swift or initial view
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ Notification permissions granted")
            } else {
                print("❌ Notification permissions denied")
            }
        }
    }

//@main
//struct ChatApp: App {
//    @StateObject private var authViewModel = AuthViewModel()
//    @StateObject private var chatViewModel = ChatViewModel()
//    
//    var body: some Scene {
//        WindowGroup {
//            ContentView()
//                .environmentObject(authViewModel)
//                .environmentObject(chatViewModel)
//        }
//    }
//}
//
//struct ContentView: View {
//    @EnvironmentObject var authViewModel: AuthViewModel
//    
//    var body: some View {
//        if authViewModel.isAuthenticated {
//            ChatListView()
//        } else {
//            LoginView()
//        }
//    }
//}
