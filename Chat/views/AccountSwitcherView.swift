import SwiftUI

struct AccountSwitcherView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @Binding var isPresented: Bool
    @State private var switchingTo: String? = nil
    
    private let gradientColors = [Color(hex: "#7373d2"), Color(hex: "#9d73d2")]
    
    var otherAccounts: [String] {
        authViewModel.savedAccounts.filter { $0 != authViewModel.currentUser }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Current account
                Section("Current Account") {
                    accountRow(
                        username: authViewModel.currentUser ?? "",
                        isCurrent: true
                    )
                }
                
                // Other saved accounts
                if !otherAccounts.isEmpty {
                    Section("Switch To") {
                        ForEach(otherAccounts, id: \.self) { username in
                            accountRow(username: username, isCurrent: false)
                        }
                    }
                }
                
                // Add account
                Section {
                    Button {
                        isPresented = false
                        // You can post a notification or use a callback
                        // to trigger showing LoginView for a new account
                        NotificationCenter.default.post(
                            name: NSNotification.Name("AddNewAccount"),
                            object: nil
                        )
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color(.systemGray5))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "plus")
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: gradientColors,
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                            Text("Add Another Account")
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: gradientColors,
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        }
                    }
                }
            }
            .navigationTitle("Accounts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { isPresented = false }
                        .foregroundStyle(
                            LinearGradient(
                                colors: gradientColors,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
            }
        }
    }
    
    @ViewBuilder
    private func accountRow(username: String, isCurrent: Bool) -> some View {
        HStack(spacing: 14) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#7373d2").opacity(0.2),
                                     Color(hex: "#9d73d2").opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                
                Text(username.prefix(1).uppercased())
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(username)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                if isCurrent {
                    Text("Active")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Tap to switch")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if isCurrent {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            } else if switchingTo == username {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isCurrent else { return }
            switchingTo = username
            
            // Small delay so the loading indicator shows
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                authViewModel.switchAccount(to: username)
                isPresented = false
            }
        }
    }
}
