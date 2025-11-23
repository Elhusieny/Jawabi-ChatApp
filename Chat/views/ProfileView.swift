
import SwiftUI
struct ProfileView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @Binding var isPresented: Bool
    @State private var showingLogoutConfirmation = false
    @State private var gradientAnimation = false
    
    // Moving color sets
    private let gradientColors1: [Color] = [
        Color.blue.opacity(0.1),
        Color.purple.opacity(0.05),
        Color.pink.opacity(0.1)
    ]
    
    private let gradientColors2: [Color] = [
        Color.purple.opacity(0.1),
        Color.blue.opacity(0.05),
        Color.cyan.opacity(0.1)
    ]
    
    private let iconGradientColors: [Color] = [.blue, .purple, .pink]
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Animated Background
                LinearGradient(
                    colors: gradientAnimation ? gradientColors1 : gradientColors2,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Profile Header
                        VStack(spacing: 16) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 80))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: iconGradientColors,
                                        startPoint: gradientAnimation ? .topLeading : .bottomLeading,
                                        endPoint: gradientAnimation ? .bottomTrailing : .topTrailing
                                    )
                                )
                                .symbolRenderingMode(.hierarchical)
                                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: gradientAnimation)
                            
                            VStack(spacing: 4) {
                                Text(authViewModel.currentUser ?? "User")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.blue, .purple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                
                                Text("Online")
                                    .font(.subheadline)
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.green, .blue],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            }
                        }
                        .padding(.vertical, 32)
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemBackground).opacity(0.9))
                        
                        // Menu Items
                        LazyVStack(spacing: 1) {
                            ProfileMenuRow(
                                icon: "star.fill",
                                gradientColors: [.yellow, .orange],
                                title: "Starred Messages",
                                gradientAnimation: gradientAnimation
                            )
                            
                            ProfileMenuRow(
                                icon: "laptopcomputer",
                                gradientColors: [.blue, .purple],
                                title: "Linked Devices",
                                gradientAnimation: gradientAnimation
                            )
                            
                            ProfileMenuRow(
                                icon: "key.fill",
                                gradientColors: [.orange, .red],
                                title: "Account",
                                gradientAnimation: gradientAnimation
                            )
                            
                            ProfileMenuRow(
                                icon: "lock.fill",
                                gradientColors: [.green, .blue],
                                title: "Privacy",
                                gradientAnimation: gradientAnimation
                            )
                            
                            ProfileMenuRow(
                                icon: "message.fill",
                                gradientColors: [.purple, .pink],
                                title: "Chats",
                                gradientAnimation: gradientAnimation
                            )
                            
                            ProfileMenuRow(
                                icon: "bell.fill",
                                gradientColors: [.red, .orange],
                                title: "Notifications",
                                gradientAnimation: gradientAnimation
                            )
                            
                            ProfileMenuRow(
                                icon: "arrow.up.arrow.down",
                                gradientColors: [.gray, .blue],
                                title: "Storage and Data",
                                gradientAnimation: gradientAnimation
                            )
                            
                            ProfileMenuRow(
                                icon: "info.circle.fill",
                                gradientColors: [.blue, .cyan],
                                title: "Help",
                                gradientAnimation: gradientAnimation
                            )
                        }
                        .background(Color(.systemBackground).opacity(0.9))
                        .padding(.top, 8)
                        
                        // Logout Button
                        Button {
                            showingLogoutConfirmation = true
                        } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.red, .orange],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                
                                Text("Log Out")
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.red, .orange],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .fontWeight(.medium)
                                
                                Spacer()
                            }
                            .padding()
                            .background(Color(.systemBackground).opacity(0.9))
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                }
            }
            .confirmationDialog("Log Out", isPresented: $showingLogoutConfirmation) {
                Button("Log Out", role: .destructive) {
                    authViewModel.logout()
                    isPresented = false
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to log out?")
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                    gradientAnimation.toggle()
                }
            }
        }
    }
}

struct ProfileMenuRow: View {
    let icon: String
    let gradientColors: [Color]
    let title: String
    let gradientAnimation: Bool
    
    var body: some View {
        Button {
            // Handle menu item tap
        } label: {
            HStack {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [gradientColors[0].opacity(0.1), gradientColors[1].opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(
                            LinearGradient(
                                colors: gradientColors,
                                startPoint: gradientAnimation ? .top : .leading,
                                endPoint: gradientAnimation ? .bottom : .trailing
                            )
                        )
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: gradientAnimation)
                }
                
                Text(title)
                    .foregroundColor(.primary)
                    .font(.system(size: 16))
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.gray, .gray.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .buttonStyle(.plain)
    }
}
