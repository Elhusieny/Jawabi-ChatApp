import SwiftUI
import PhotosUI

struct RequestAccessView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @State private var userName = ""
    @State private var email = ""
    @State private var displayName = ""
    @State private var phoneNumber = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var companyName = ""
    @State private var profileImage: UIImage?
    @State private var showImagePicker = false
    @State private var validationErrors: [String] = []
    @State private var isPasswordVisible = false
    @State private var isConfirmPasswordVisible = false
    @State private var gradientAnimation = false
    @State private var serverUrl = ""
    @State private var showSuccessAlert = false

    private var isFormValid: Bool {
        validationErrors.isEmpty &&
        !userName.isEmpty &&
        !email.isEmpty &&
        !displayName.isEmpty &&
        !phoneNumber.isEmpty &&
        !password.isEmpty &&
        !companyName.isEmpty &&
        password == confirmPassword
    }
    
    // Define the main color as static computed properties
    private var primaryColor: Color { Color(hex: "#7373d2") }
    private var primaryColorLight: Color { primaryColor.opacity(0.2) }
    private var primaryColorDark: Color { primaryColor.opacity(0.8) }
    
    // Computed gradient colors
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
    
    private var buttonGradient1: [Color] {
        [primaryColor, Color(hex: "#9d73d2")]
    }
    
    private var buttonGradient2: [Color] {
        [Color(hex: "#73d2a3"), primaryColor]
    }
    
    var body: some View {
        ZStack {
            // Animated Background
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
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Request Access")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [primaryColor, Color(hex: "#9d73d2")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Text("Request access to our platform")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    // Profile Picture Section
                    VStack(spacing: 12) {
                        Button {
                            showImagePicker = true
                        } label: {
                            ZStack {
                                if let profileImage = profileImage {
                                    Image(uiImage: profileImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(
                                                    LinearGradient(
                                                        colors: gradientAnimation ? buttonGradient1 : buttonGradient2,
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 3
                                                )
                                        )
                                } else {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [primaryColor.opacity(0.2), Color(hex: "#9d73d2").opacity(0.2)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 100, height: 100)
                                        .overlay(
                                            Image(systemName: "person.circle.fill")
                                                .font(.system(size: 50))
                                                .foregroundStyle(
                                                    LinearGradient(
                                                        colors: gradientAnimation ? buttonGradient1 : buttonGradient2,
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                        )
                                }
                                
                                // Animated Edit button
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: gradientAnimation ? buttonGradient1 : buttonGradient2,
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white)
                                    )
                                    .offset(x: 35, y: 35)
                            }
                        }
                        .buttonStyle(.plain)
                        
                        Text("Tap to add profile picture")
                            .font(.subheadline)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: gradientAnimation ? buttonGradient1 : buttonGradient2,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .fontWeight(.medium)
                    }
                    
                    // Form Fields
                    VStack(spacing: 20) {
                        // Personal Information
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Personal Information")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: gradientAnimation ? [primaryColor, Color(hex: "#9d73d2")] : [Color(hex: "#73d2a3"), primaryColor],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .padding(.bottom, 4)
                            
                            AnimatedIconTextField(
                                title: "Username",
                                text: $userName,
                                icon: "person.fill",
                                gradientColors: iconGradientColors,
                                isAnimating: gradientAnimation,
                                keyboardType: .default
                            )
                            
                            AnimatedIconTextField(
                                title: "Email",
                                text: $email,
                                icon: "envelope.fill",
                                gradientColors: iconGradientColors,
                                isAnimating: gradientAnimation,
                                keyboardType: .emailAddress
                            )
                            
                            AnimatedIconTextField(
                                title: "Display Name",
                                text: $displayName,
                                icon: "tag.fill",
                                gradientColors: iconGradientColors,
                                isAnimating: gradientAnimation,
                                keyboardType: .default
                            )
                            
                            AnimatedIconTextField(
                                title: "Phone Number",
                                text: $phoneNumber,
                                icon: "phone.fill",
                                gradientColors: iconGradientColors,
                                isAnimating: gradientAnimation,
                                keyboardType: .phonePad
                            )
                        }
                        
                        // Company Information
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Company Information")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: gradientAnimation ? [Color(hex: "#9d73d2"), primaryColor] : [primaryColor, Color(hex: "#73d2a3")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .padding(.bottom, 4)
                            
                            AnimatedIconTextField(
                                title: "Company Name",
                                text: $companyName,
                                icon: "building.2.fill",
                                gradientColors: iconGradientColors,
                                isAnimating: gradientAnimation,
                                keyboardType: .default
                            )
                        }
                        
                        // Server Configuration
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Server Configuration")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: gradientAnimation ? [primaryColor, Color(hex: "#73d2a3")] : [Color(hex: "#9d73d2"), primaryColor],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .padding(.bottom, 4)
                            
                            AnimatedIconTextField(
                                title: "Server URL (Optional)",
                                text: $serverUrl,
                                icon: "server.rack",
                                gradientColors: iconGradientColors,
                                isAnimating: gradientAnimation,
                                keyboardType: .URL
                            )
                        }
                        
                        // Security
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Security")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: gradientAnimation ? [Color(hex: "#d273a3"), primaryColor] : [primaryColor, Color(hex: "#9d73d2")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .padding(.bottom, 4)
                            
                            AnimatedIconSecureField(
                                title: "Password",
                                text: $password,
                                icon: "lock.fill",
                                gradientColors: iconGradientColors,
                                isAnimating: gradientAnimation,
                                isPasswordVisible: $isPasswordVisible
                            )
                            
                            AnimatedIconSecureField(
                                title: "Confirm Password",
                                text: $confirmPassword,
                                icon: "lock.fill",
                                gradientColors: iconGradientColors,
                                isAnimating: gradientAnimation,
                                isPasswordVisible: $isConfirmPasswordVisible
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    // Validation Errors
                    if !validationErrors.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(validationErrors, id: \.self) { error in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.red, .orange],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .font(.caption)
                                    
                                    Text(error)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // Server Error
                    if let error = authViewModel.errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.orange, .yellow],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                            
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.orange)
                                .multilineTextAlignment(.leading)
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // Request Access Button
                    VStack(spacing: 16) {
                        if authViewModel.isLoading {
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(primaryColor)
                        } else {
                            Button(action: requestAccess) {
                                HStack {
                                    Text("Request Access")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                    
                                    Image(systemName: "arrow.right.circle.fill")
                                        .font(.headline)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: gradientAnimation ? buttonGradient1 : buttonGradient2,
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                                .shadow(color: primaryColor.opacity(0.3), radius: 8, x: 0, y: 4)
                                .scaleEffect(gradientAnimation ? 1.02 : 1.0)
                            }
                            .disabled(!isFormValid)
                            .opacity(isFormValid ? 1.0 : 0.6)
                            .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: gradientAnimation)
                        }
                        
                        Button("Already have access? Sign In") {
                            dismiss()
                        }
                        .font(.subheadline)
                        .foregroundStyle(
                            LinearGradient(
                                colors: gradientAnimation ? buttonGradient1 : buttonGradient2,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .fontWeight(.medium)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationTitle("Request Access")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $profileImage)
        }
        .alert("Access Request Submitted", isPresented: $showSuccessAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your request for access has been submitted successfully. You will be notified once your account is approved.")
        }
        .onChange(of: userName) { _ in validateForm() }
        .onChange(of: email) { _ in validateForm() }
        .onChange(of: displayName) { _ in validateForm() }
        .onChange(of: phoneNumber) { _ in validateForm() }
        .onChange(of: companyName) { _ in validateForm() }
        .onChange(of: password) { _ in validateForm() }
        .onChange(of: confirmPassword) { _ in validateForm() }
        .accentColor(primaryColor)
        .onReceive(authViewModel.$showRequestAccessSuccess) { success in
            if success {
                showSuccessAlert = true
                authViewModel.showRequestAccessSuccess = false
            }
        }
    }
    
    private func requestAccess() {
        validateForm()
        guard isFormValid else { return }
        
        let imageData = profileImage?.jpegData(compressionQuality: 0.7)
        authViewModel.requestAccess(
            userName: userName,
            email: email,
            displayName: displayName,
            phoneNumber: phoneNumber,
            password: password,
            companyName: companyName,
            profilePicture: imageData,
            serverUrl: serverUrl.isEmpty ? nil : serverUrl
        )
    }
    
    private func validateForm() {
        validationErrors.removeAll()
        
        if userName.isEmpty {
            validationErrors.append("Username is required")
        }
        
        if email.isEmpty {
            validationErrors.append("Email is required")
        } else if !isValidEmail(email) {
            validationErrors.append("Please enter a valid email address")
        }
        
        if displayName.isEmpty {
            validationErrors.append("Display name is required")
        }
        
        if phoneNumber.isEmpty {
            validationErrors.append("Phone number is required")
        }
        
        if companyName.isEmpty {
            validationErrors.append("Company name is required")
        }
        
        if password.isEmpty {
            validationErrors.append("Password is required")
        } else if password.count < 6 {
            validationErrors.append("Password must be at least 6 characters")
        }
        
        if confirmPassword != password {
            validationErrors.append("Passwords do not match")
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Z0-9a-z.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
}

// MARK: - Preview
struct RequestAccessView_Previews: PreviewProvider {
    static var previews: some View {
        RequestAccessView()
            .environmentObject(AuthViewModel())
    }
}