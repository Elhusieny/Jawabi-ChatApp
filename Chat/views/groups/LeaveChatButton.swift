//
//  LeaveChatButton.swift
//  Chat
//
//  Created by Ahmed Elhussieny on 24/05/2026.
//


// LeaveChatButton.swift
import SwiftUI

struct LeaveChatButton: View {
    let chatId: Int
    let chatName: String
    let chatType: Int // 0 = group, 1 = private
    @ObservedObject var chatViewModel: ChatViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showingConfirmation = false
    @State private var isLeaving = false
    
    // Only show for group chats
    private var isGroupChat: Bool { chatType == 0 }
    
    var body: some View {
        Group {
            if isGroupChat {
                Button(role: .destructive) {
                    showingConfirmation = true
                } label: {
                    HStack {
                        if isLeaving {
                            ProgressView()
                                .tint(.white)
                                .padding(.trailing, 8)
                        }
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text(isLeaving ? "Leaving..." : "Leave Group")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(isLeaving ? Color.gray : Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isLeaving)
                .confirmationDialog(
                    "Leave \(chatName)?",
                    isPresented: $showingConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Leave", role: .destructive) {
                        performLeaveChat()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("You won't receive messages from this group anymore. You can rejoin later if invited.")
                }
            }
        }
    }
    
    private func performLeaveChat() {
        withAnimation {
            isLeaving = true
        }
        
        chatViewModel.leaveChat(chatId: chatId) { success in
            DispatchQueue.main.async {
                withAnimation {
                    isLeaving = false
                }
                
                if success {
                    // Show success message
                    showAlert(
                        title: "Left Group",
                        message: "You have successfully left \"\(chatName)\""
                    ) {
                        dismiss()
                    }
                } else {
                    // Show error message
                    showAlert(
                        title: "Error",
                        message: chatViewModel.errorMessage ?? "Failed to leave group. Please try again."
                    )
                }
            }
        }
    }
    
    private func showAlert(title: String, message: String, onDismiss: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            onDismiss?()
        })
        
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(alert, animated: true)
        }
    }
}