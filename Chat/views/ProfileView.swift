import SwiftUI

struct ProfileView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @Binding var isPresented: Bool
    @State private var showingLogoutConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var gradientAnimation = false
    
    // For navigation to chats
    @Environment(\.dismiss) var dismiss
    
    // Define the main color as static computed properties - SAME AS ChatListView/RegisterView
    private var primaryColor: Color { Color(hex: "#7373d2") }
    private var primaryColorLight: Color { primaryColor.opacity(0.2) }
    private var primaryColorDark: Color { primaryColor.opacity(0.8) }
    
    // Computed gradient colors - SAME AS ChatListView/RegisterView
    private var gradientColors1: [Color] {
        [
            primaryColor.opacity(0.1),
            Color(hex: "#9d73d2").opacity(0.05),
            Color(hex: "#d273a3").opacity(0.1)
        ]
    }
    
    private var gradientColors2: [Color] {
        [
            Color(hex: "#9d73d2").opacity(0.1),
            primaryColor.opacity(0.05),
            Color(hex: "#73d2b8").opacity(0.1)
        ]
    }
    
    private var iconGradientColors: [Color] {
        [primaryColor, Color(hex: "#9d73d2"), Color(hex: "#d273a3")]
    }
    
    // Button gradient colors using the same scheme
    private var buttonGradient1: [Color] {
        [primaryColor, Color(hex: "#9d73d2")]
    }
    
    private var buttonGradient2: [Color] {
        [Color(hex: "#73d2a3"), primaryColor]
    }
    
    // Dark purple gradient for buttons (same as Account Information)
    private var darkPurpleGradient: [Color] {
        [Color(hex: "#5a5aa8"), primaryColor] // Darker purple to primary purple
    }
    
    // Even darker gradient for delete button
    private var darkDeleteGradient: [Color] {
        [Color(hex: "#5a5aa8"), primaryColor] // Dark red to dark purple
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Animated Background - SAME GRADIENT
                LinearGradient(
                    colors: gradientAnimation ? gradientColors1 : gradientColors2,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                if authViewModel.isLoading {
                    loadingOverlay
                }
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Profile Header with User Info
                        profileHeader
                        
                        // User Info Section
                        if let userInfo = authViewModel.userInfo {
                            userInfoSection(userInfo: userInfo)
                        }
                        
                        // Menu Items
                        menuItems
                        
                        // Action Buttons
                        actionButtons
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
                            colors: darkPurpleGradient,
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
            .confirmationDialog("Delete Account", isPresented: $showingDeleteConfirmation) {
                Button("Delete Account", role: .destructive) {
                    authViewModel.deleteAccount()
                    // Don't dismiss immediately - wait for response
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This action cannot be undone. All your data will be permanently deleted.")
            }
            .alert("Account Deletion", isPresented: $authViewModel.showAlert) {
                Button("OK", role: .cancel) {
                    if authViewModel.alertMessage.contains("successfully") {
                        // If deletion was successful, dismiss the profile view
                        isPresented = false
                    }
                }
            } message: {
                Text(authViewModel.alertMessage)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                    gradientAnimation.toggle()
                }
                
                // Load user info when view appears
                authViewModel.loadUserInfo()
            }
            .onChange(of: authViewModel.isAuthenticated) { isAuthenticated in
                if !isAuthenticated {
                    // If user is no longer authenticated (after delete), dismiss
                    isPresented = false
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Profile Picture
            if let profilePicture = authViewModel.userInfo?.profilePicture,
               !profilePicture.isEmpty,
               let url = URL(string: profilePicture) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        placeholderProfileImage
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: darkPurpleGradient,
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 3
                                    )
                            )
                            .shadow(color: primaryColor.opacity(0.3), radius: 10)
                    case .failure:
                        placeholderProfileImage
                    @unknown default:
                        placeholderProfileImage
                    }
                }
            } else {
                placeholderProfileImage
            }
            
            // User Name
            VStack(spacing: 4) {
                Text(authViewModel.currentUser ?? "User")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(
                        LinearGradient(
                            colors: darkPurpleGradient,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("Online")
                    .font(.subheadline)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#73d2a3"), primaryColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground).opacity(0.9))
    }
    
    private var placeholderProfileImage: some View {
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
    }
    
    private func userInfoSection(userInfo: AuthViewModel.UserInfo) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Account Information")
                .font(.headline)
                .foregroundStyle(
                    LinearGradient(
                        colors: darkPurpleGradient,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                if let displayName = userInfo.displayName, !displayName.isEmpty {
                    infoRow(icon: "person.fill", title: "Display Name", value: displayName)
                }
                
                if let userName = userInfo.userName, !userName.isEmpty {
                    infoRow(icon: "at", title: "Username", value: userName)
                }
                
                if let email = userInfo.email, !email.isEmpty {
                    infoRow(icon: "envelope.fill", title: "Email", value: email)
                }
                
                if let phoneNumber = userInfo.phoneNumber, !phoneNumber.isEmpty {
                    infoRow(icon: "phone.fill", title: "Phone", value: phoneNumber)
                }
            }
            .padding()
            .background(Color(.systemBackground).opacity(0.9))
            .cornerRadius(12)
            .padding(.horizontal)
        }
        .padding(.vertical, 16)
    }
    
    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(
                    LinearGradient(
                        colors: iconGradientColors,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.body)
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
    }
    
    private var menuItems: some View {
        LazyVStack(spacing: 1) {
            // Chats Button - Navigates to Chat List
            ProfileMenuRow(
                icon: "message.fill",
                gradientColors: darkPurpleGradient, // Same dark purple gradient
                title: "My Chats",
                gradientAnimation: gradientAnimation
            ) {
                // Dismiss profile and show chat list
                isPresented = false
                // Note: The chat list is already the main screen,
                // so dismissing will return to it
            }
        }
        .background(Color(.systemBackground).opacity(0.9))
        .padding(.top, 8)
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Logout Button - DARK PURPLE GRADIENT
            Button {
                showingLogoutConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundStyle(.white)
                    
                    Text("Log Out")
                        .foregroundStyle(.white)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding()
                .background(
                    LinearGradient(
                        colors: darkPurpleGradient, // Same dark purple gradient
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(10)
                .shadow(color: primaryColor.opacity(0.2), radius: 4, x: 0, y: 2)
            }
            
            // Delete Account Button - DARK RED-PURPLE GRADIENT
            Button {
                showingDeleteConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash.fill")
                        .foregroundStyle(.white)
                    
                    Text("Delete Account")
                        .foregroundStyle(.white)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding()
                .background(
                    LinearGradient(
                        colors: darkDeleteGradient, // Dark red to dark purple
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(10)
                .shadow(color: Color(hex: "#a85a5a").opacity(0.3), radius: 4, x: 0, y: 2)
            }
        }
        .padding(.horizontal)
        .padding(.top, 24)
        .padding(.bottom, 32)
    }
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text("Deleting account...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(30)
            .background(
                LinearGradient(
                    colors: darkPurpleGradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(20)
            .shadow(radius: 10)
        }
    }
}

struct ProfileMenuRow: View {
    let icon: String
    let gradientColors: [Color] // Static colors, not animated
    let title: String
    let gradientAnimation: Bool
    let action: () -> Void
    
    init(icon: String, gradientColors: [Color], title: String, gradientAnimation: Bool, action: @escaping () -> Void) {
        self.icon = icon
        self.gradientColors = gradientColors
        self.title = title
        self.gradientAnimation = gradientAnimation
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
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
                                startPoint: .leading, // Static
                                endPoint: .trailing   // Static
                            )
                        )
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
