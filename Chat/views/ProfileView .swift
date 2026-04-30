import SwiftUI
import PhotosUI

struct ProfileView: View {
    @StateObject private var profilePictureViewModel = ProfilePictureViewModel()
    @ObservedObject var authViewModel: AuthViewModel
    @Binding var isPresented: Bool
    @State private var showingImageSource = false
    @State private var imageSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var showingLogoutConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var gradientAnimation = false
    // Add to ProfileView @State properties
    @State  var showingAccountSwitcher = false

    private let primaryColor = Color(hex: "#7373d2")
    private let gradientColors = [Color(hex: "#7373d2"), Color(hex: "#9d73d2")]
    
    // Computed gradient colors for the background
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
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: gradientAnimation ? gradientColors1 : gradientColors2,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .onAppear {
                    withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                        gradientAnimation.toggle()
                    }
                }
                
                if profilePictureViewModel.isLoading && profilePictureViewModel.userProfile == nil {
                    LoadingView(primaryColor: primaryColor)
                } else {
                    ScrollView {
                        VStack(spacing: 30) {
                            // Profile Picture Section
                            ProfilePictureSection(
                                profilePictureViewModel: profilePictureViewModel,
                                showingImageSource: $showingImageSource,
                                userInfo: authViewModel.userInfo
                            )
                            
                            // Profile Info Section
                            ProfileInfoSection(
                                profilePictureViewModel: profilePictureViewModel,
                                userInfo: authViewModel.userInfo
                            )
                            
                            // Upload Status
                            if profilePictureViewModel.isUploading {
                                UploadProgressView(
                                    progress: profilePictureViewModel.uploadProgress,
                                    primaryColor: primaryColor
                                )
                            }
                            
                            // Update the ActionButtonsSection call in ProfileView
                            ActionButtonsSection(
                                showingLogoutConfirmation: $showingLogoutConfirmation,
                                showingDeleteConfirmation: $showingDeleteConfirmation,
                                showingAccountSwitcher: $showingAccountSwitcher,  // Add this
                                authViewModel: authViewModel,
                                isPresented: $isPresented
                            )
                            
                            Spacer()
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    closeButton
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if profilePictureViewModel.userProfile != nil && !profilePictureViewModel.isEditingProfile {
                        editButton
                    }
                }
            }
            .sheet(isPresented: $profilePictureViewModel.showImagePicker) {
                CameraImagePicker(sourceType: imageSource) { image in
                    profilePictureViewModel.handleImageSelection(image)
                }
            }
            .actionSheet(isPresented: $showingImageSource) {
                ActionSheet(
                    title: Text("Change Profile Picture"),
                    message: Text("Choose a source"),
                    buttons: [
                        .default(Text("Take Photo")) {
                            imageSource = .camera
                            profilePictureViewModel.showImagePicker = true
                        },
                        .default(Text("Choose from Library")) {
                            imageSource = .photoLibrary
                            profilePictureViewModel.showImagePicker = true
                        },
                        .cancel()
                    ]
                )
            }
            // Add the sheet to ProfileView's body modifiers
            .sheet(isPresented: $showingAccountSwitcher) {
                AccountSwitcherView(
                    authViewModel: authViewModel,
                    isPresented: $showingAccountSwitcher
                )
            }
            .onAppear {
                authViewModel.loadSavedAccounts()
            }
            .alert("Success", isPresented: .constant(profilePictureViewModel.successMessage != nil)) {
                Button("OK") {
                    profilePictureViewModel.successMessage = nil
                }
            } message: {
                Text(profilePictureViewModel.successMessage ?? "")
            }
            .alert("Error", isPresented: .constant(profilePictureViewModel.errorMessage != nil)) {
                Button("OK") {
                    profilePictureViewModel.errorMessage = nil
                }
            } message: {
                Text(profilePictureViewModel.errorMessage ?? "")
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
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This action cannot be undone. All your data will be permanently deleted.")
            }
            .onAppear {
                profilePictureViewModel.loadUserProfile()
            }
            // In ProfileView, update the logout confirmation
            .confirmationDialog("Log Out", isPresented: $showingLogoutConfirmation) {
                Button("Log Out", role: .destructive) {
                    // Set last username before logout
                    if let currentUsername = authViewModel.currentUser {
                        UserDefaults.standard.set(currentUsername, forKey: "lastUsername")
                    }
                    
                    authViewModel.logout()
                    isPresented = false
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to log out?\nYour account will be saved for quick login.")
            }
        }
    }
    
    // MARK: - Toolbar Buttons
    
    private var closeButton: some View {
        Button("Close") {
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
    
    private var editButton: some View {
        Button("Edit") {
            profilePictureViewModel.isEditingProfile = true
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

// MARK: - Subviews

struct ProfilePictureSection: View {
    @ObservedObject var profilePictureViewModel: ProfilePictureViewModel
    @Binding var showingImageSource: Bool
    let userInfo: AuthViewModel.UserInfo?
    
    private let gradientColors = [Color(hex: "#7373d2"), Color(hex: "#9d73d2")]
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack(alignment: .bottomTrailing) {
                // Profile Image
                if let selectedImage = profilePictureViewModel.selectedImage {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 150, height: 150)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: gradientColors,
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 4
                                )
                        )
                        .shadow(color: Color(hex: "#7373d2").opacity(0.3), radius: 10)
                } else if let userProfile = profilePictureViewModel.userProfile {
                    if userProfile.isDefaultImage {
                        // Default image with initials
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#7373d2").opacity(0.3), Color(hex: "#9d73d2").opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 150, height: 150)
                            .overlay(
                                Text(profilePictureViewModel.getUserInitials())
                                    .font(.system(size: 50, weight: .bold))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: gradientColors,
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: gradientColors,
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 4
                                    )
                            )
                    } else {
                        // Actual profile image
                        AsyncImage(url: URL(string: userProfile.fullPictureUrl)) { phase in
                            switch phase {
                            case .empty:
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 150, height: 150)
                                    .overlay(
                                        ProgressView()
                                            .scaleEffect(1.2)
                                            .tint(Color(hex: "#7373d2"))
                                    )
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 150, height: 150)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                LinearGradient(
                                                    colors: gradientColors,
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 4
                                            )
                                    )
                            case .failure:
                                // Fallback
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: "#7373d2").opacity(0.3), Color(hex: "#9d73d2").opacity(0.3)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 150, height: 150)
                                    .overlay(
                                        Text(profilePictureViewModel.getUserInitials())
                                            .font(.system(size: 50, weight: .bold))
                                            .foregroundStyle(
                                                LinearGradient(
                                                    colors: gradientColors,
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                    )
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }
                } else if let userInfo = userInfo,
                          let profilePicture = userInfo.profilePicture,
                          !profilePicture.isEmpty,
                          let url = URL(string: profilePicture) {
                    // Use authViewModel user info
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            placeholderProfileImage
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 150, height: 150)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                colors: gradientColors,
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 4
                                        )
                                )
                        case .failure:
                            placeholderProfileImage
                        @unknown default:
                            placeholderProfileImage
                        }
                    }
                } else {
                    placeholderProfileImage
                }
                
                // Edit Button
                Button(action: { showingImageSource = true }) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#73d2a3"), Color.green],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.title3)
                                .foregroundColor(.white)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 5)
                }
                .offset(x: 10, y: 10)
            }
            
            Text("Tap camera to change photo")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private var placeholderProfileImage: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Color(hex: "#7373d2").opacity(0.3), Color(hex: "#9d73d2").opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 150, height: 150)
            .overlay(
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#7373d2"), Color(hex: "#9d73d2")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
    }
}

struct ProfileInfoSection: View {
    @ObservedObject var profilePictureViewModel: ProfilePictureViewModel
    let userInfo: AuthViewModel.UserInfo?
    
    private let gradientColors = [Color(hex: "#7373d2"), Color(hex: "#9d73d2")]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Profile Information")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            VStack(spacing: 16) {
                // Name
                infoRow(
                    title: "Name",
                    value: profilePictureViewModel.userProfile?.displayName ?? userInfo?.displayName ?? "Unknown",
                    isEditing: profilePictureViewModel.isEditingProfile,
                    binding: $profilePictureViewModel.tempName,
                    placeholder: "Enter your name"
                )
                
                // Email
                infoRow(
                    title: "Email",
                    value: profilePictureViewModel.userProfile?.email ?? userInfo?.email ?? "No email",
                    isEditing: profilePictureViewModel.isEditingProfile,
                    binding: $profilePictureViewModel.tempEmail,
                    placeholder: "Enter your email"
                )
                
                // Phone
                infoRow(
                    title: "Phone Number",
                    value: profilePictureViewModel.formatPhoneNumber(profilePictureViewModel.userProfile?.phoneNumber ?? userInfo?.phoneNumber ?? ""),
                    isEditing: profilePictureViewModel.isEditingProfile,
                    binding: $profilePictureViewModel.tempPhoneNumber,
                    placeholder: "Enter your phone number"
                )
            }
            
            if profilePictureViewModel.isEditingProfile {
                editButtons
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
    
    @ViewBuilder
    private func infoRow(
        title: String,
        value: String,
        isEditing: Bool,
        binding: Binding<String>,
        placeholder: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            if isEditing {
                TextField(placeholder, text: binding)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
            } else {
                Text(value)
                    .font(.body)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
        }
    }
    
    private var editButtons: some View {
        HStack(spacing: 12) {
            Button("Cancel") {
                profilePictureViewModel.cancelEdit()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray5))
            .foregroundColor(.primary)
            .cornerRadius(10)
            
            Button("Save Changes") {
                profilePictureViewModel.updateProfileInfo()
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
            .cornerRadius(10)
            .disabled(profilePictureViewModel.isLoading)
        }
    }
}

// Update ActionButtonsSection in ProfileView

struct ActionButtonsSection: View {
    @Binding var showingLogoutConfirmation: Bool
    @Binding var showingDeleteConfirmation: Bool
    @Binding var showingAccountSwitcher: Bool  // NEW
    @ObservedObject var authViewModel: AuthViewModel
    @Binding var isPresented: Bool
    
    private let darkPurpleGradient = [Color(hex: "#5a5aa8"), Color(hex: "#7373d2")]
    private let darkDeleteGradient = [Color(hex: "#a85a5a"), Color(hex: "#d27373")]
    private let switchGradient = [Color(hex: "#5a7aa8"), Color(hex: "#739dd2")] // NEW: Blue-ish gradient for switch
    
    var body: some View {
        VStack(spacing: 12) {
            // NEW: Switch Account Button (only show if there are saved accounts)
            if authViewModel.savedAccounts.count > 1 {
                Button {
                    showingAccountSwitcher = true
                } label: {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundStyle(.white)
                        
                        Text("Switch Account")
                            .foregroundStyle(.white)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text("\(authViewModel.savedAccounts.count) accounts")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding()
                    .background(
                        LinearGradient(
                            colors: switchGradient,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(10)
                    .shadow(color: Color(hex: "#739dd2").opacity(0.2), radius: 4, x: 0, y: 2)
                }
            }
            
            // Existing Log Out button
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
                }
                .padding()
                .background(
                    LinearGradient(
                        colors: darkPurpleGradient,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(10)
                .shadow(color: Color(hex: "#7373d2").opacity(0.2), radius: 4, x: 0, y: 2)
            }
            
            // Existing Delete Account button
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
                }
                .padding()
                .background(
                    LinearGradient(
                        colors: darkDeleteGradient,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(10)
                .shadow(color: Color(hex: "#a85a5a").opacity(0.3), radius: 4, x: 0, y: 2)
            }
        }
        .padding(.top, 20)
    }
}
// MARK: - Reuse existing views

struct UploadProgressView: View {
    let progress: Double
    let primaryColor: Color
    
    var body: some View {
        VStack(spacing: 12) {
            ProgressView(value: progress, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle())
                .tint(primaryColor)
                .frame(height: 6)
            
            HStack {
                Text("Uploading...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundStyle(primaryColor)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.05), radius: 3)
    }
}

struct LoadingView: View {
    let primaryColor: Color
    
    var body: some View {
        VStack {
            ProgressView()
                .scaleEffect(1.5)
                .tint(primaryColor)
                .padding()
            
            Text("Loading profile...")
                .foregroundStyle(.secondary)
        }
    }
}
