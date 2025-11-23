
// App.swift or your main app file
import SwiftUI

@main
struct ChatApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isAuthenticated {
                    ChatListView()
                        .environmentObject(authViewModel)
                } else {
                    LoginView()
                        .environmentObject(authViewModel)
                }
            }
            .onAppear {
                authViewModel.checkAuthenticationStatus()
            }
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
