// AccountSwitcherView.swift
import SwiftUI

struct AccountSwitcherView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @Binding var isPresented: Bool
    @State private var selectedAccount: String?
    @State private var showingAddAccount = false
    
    private let gradientColors = [Color(hex: "#7373d2"), Color(hex: "#9d73d2")]
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [gradientColors[0].opacity(0.05), gradientColors[1].opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    if authViewModel.savedAccounts.isEmpty {
                        emptyStateView
                    } else {
                        accountsListView
                    }
                    
                    addAccountButton
                }
                .padding()
            }
            .navigationTitle("Switch Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundStyle(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                }
            }
            .onAppear {
                authViewModel.loadSavedAccounts()
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 70))
                .foregroundStyle(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Text("No Saved Accounts")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Accounts you log into will appear here for quick switching")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxHeight: .infinity)
    }
    
    private var accountsListView: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(authViewModel.savedAccounts, id: \.self) { username in
                    AccountRow(
                        username: username,
                        isCurrentAccount: username == authViewModel.currentUser,
                        onSelect: {
                            selectedAccount = username
                            confirmSwitch()
                        },
                        onDelete: {
                            authViewModel.deleteSavedAccount(username)
                        }
                    )
                }
            }
        }
    }
    
    private var addAccountButton: some View {
        Button {
            showingAddAccount = true
            isPresented = false
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Add Another Account")
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(12)
        }
    }
    
    private func confirmSwitch() {
        guard let username = selectedAccount else { return }
        
        // Show confirmation alert
        let alert = UIAlertController(
            title: "Switch Account",
            message: "Switch to \(username)? You'll be logged out of the current account.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Switch", style: .default) { _ in
            authViewModel.switchToAccount(username: username)
            isPresented = false
        })
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(alert, animated: true)
        }
    }
}

struct AccountRow: View {
    let username: String
    let isCurrentAccount: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    private let gradientColors = [Color(hex: "#7373d2"), Color(hex: "#9d73d2")]
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 15) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    Text(String(username.prefix(1).uppercased()))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(username)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if isCurrentAccount {
                        Text("Current Account")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
                
                if !isCurrentAccount {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isCurrentAccount ? 
                        LinearGradient(colors: gradientColors, startPoint: .leading, endPoint: .trailing) :
                        LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing),
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(.plain)
    }
}