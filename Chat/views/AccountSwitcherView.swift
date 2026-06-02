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
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        authViewModel.deleteSavedAccount(username)
                                    } label: {
                                        Label("Remove", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }

                // Add account
                Section {
                    Button {
                        isPresented = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            authViewModel.logoutToAddAccount()
                        }
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
                                    .fontWeight(.semibold)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Add Another Account")
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: gradientColors,
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .fontWeight(.medium)

                                Text("Log out and sign in to a new account")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                } footer: {
                    if !otherAccounts.isEmpty {
                        Text("Swipe left on an account to remove it.")
                            .font(.caption)
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
            // Dismiss automatically once switch login completes
            .onChange(of: authViewModel.isAuthenticated) { isAuthenticated in
                if isAuthenticated, switchingTo != nil {
                    switchingTo = nil
                    isPresented = false
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
                        isCurrent
                            ? LinearGradient(
                                colors: gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [Color(hex: "#7373d2").opacity(0.15),
                                         Color(hex: "#9d73d2").opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
                    .frame(width: 44, height: 44)

                Text(username.prefix(1).uppercased())
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isCurrent ? .white : Color(hex: "#7373d2"))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(username)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Text(isCurrent ? "Currently active" : "Tap to switch")
                    .font(.caption)
                    .foregroundColor(isCurrent ? Color(hex: "#7373d2") : .secondary)
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
                    .font(.title3)
            } else if switchingTo == username {
                ProgressView()
                    .scaleEffect(0.85)
                    .tint(Color(hex: "#7373d2"))
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .opacity(switchingTo != nil && switchingTo != username ? 0.4 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: switchingTo)
        .onTapGesture {
            guard !isCurrent, switchingTo == nil else { return }
            switchingTo = username
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                authViewModel.switchAccount(to: username)
            }
        }
    }
}
