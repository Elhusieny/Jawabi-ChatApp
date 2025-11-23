import SwiftUI
import PhotosUI

struct RegisterView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @State private var userName = ""
    @State private var email = ""
    @State private var displayName = ""
    @State private var phoneNumber = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var profileImage: UIImage?
    @State private var showImagePicker = false
    @State private var validationErrors: [String] = []
    @State private var isPasswordVisible = false
    @State private var isConfirmPasswordVisible = false
    @State private var gradientAnimation = false
    
    private var isFormValid: Bool {
        validationErrors.isEmpty &&
        !userName.isEmpty &&
        !email.isEmpty &&
        !displayName.isEmpty &&
        !phoneNumber.isEmpty &&
        !password.isEmpty &&
        password == confirmPassword
    }
    
    // Moving color sets
    private let gradientColors1: [Color] = [
        Color.blue.opacity(0.3),
        Color.purple.opacity(0.2),
        Color.pink.opacity(0.3)
    ]
    
    private let gradientColors2: [Color] = [
        Color.purple.opacity(0.3),
        Color.blue.opacity(0.2),
        Color.cyan.opacity(0.3)
    ]
    
    private let buttonGradient1: [Color] = [Color.blue, Color.purple]
    private let buttonGradient2: [Color] = [Color.purple, Color.pink]
    
    // Icon gradient sets
    private let iconGradients: [[Color]] = [
        [.blue, .purple],
        [.purple, .pink],
        [.pink, .orange],
        [.cyan, .blue],
        [.indigo, .purple],
        [.teal, .green]
    ]
    
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
                        Text("Create Account")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("Join our community today")
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
                                                .stroke(LinearGradient(
                                                    colors: gradientAnimation ? [.blue, .purple] : [.purple, .pink],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ), lineWidth: 3)
                                        )
                                } else {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
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
                                                        colors: gradientAnimation ? [.blue, .purple] : [.purple, .pink],
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
                                            colors: gradientAnimation ? [.blue, .purple] : [.purple, .pink],
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
                                    colors: gradientAnimation ? [.blue, .purple] : [.purple, .pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .fontWeight(.medium)
                    }
                    
                    // Form Fields
                    VStack(spacing: 20) {
                        // Profile Information
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Profile Information")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: gradientAnimation ? [.blue, .purple] : [.purple, .pink],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .padding(.bottom, 4)
                            
                            AnimatedIconTextField(
                                title: "Username",
                                text: $userName,
                                icon: "person.fill",
                                gradientColors: iconGradients[0],
                                isAnimating: gradientAnimation,
                                keyboardType: .default
                            )
                            
                            AnimatedIconTextField(
                                title: "Email",
                                text: $email,
                                icon: "envelope.fill",
                                gradientColors: iconGradients[1],
                                isAnimating: gradientAnimation,
                                keyboardType: .emailAddress
                            )
                            
                            AnimatedIconTextField(
                                title: "Display Name",
                                text: $displayName,
                                icon: "tag.fill",
                                gradientColors: iconGradients[2],
                                isAnimating: gradientAnimation,
                                keyboardType: .default
                            )
                            
                            AnimatedIconTextField(
                                title: "Phone Number",
                                text: $phoneNumber,
                                icon: "phone.fill",
                                gradientColors: iconGradients[3],
                                isAnimating: gradientAnimation,
                                keyboardType: .phonePad
                            )
                        }
                        
                        // Security
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Security")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: gradientAnimation ? [.purple, .blue] : [.blue, .cyan],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .padding(.bottom, 4)
                            
                            AnimatedIconSecureField(
                                title: "Password",
                                text: $password,
                                icon: "lock.fill",
                                gradientColors: iconGradients[4],
                                isAnimating: gradientAnimation,
                                isPasswordVisible: $isPasswordVisible
                            )
                            
                            AnimatedIconSecureField(
                                title: "Confirm Password",
                                text: $confirmPassword,
                                icon: "lock.fill",
                                gradientColors: iconGradients[5],
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
                    
                    // Register Button
                    VStack(spacing: 16) {
                        if authViewModel.isLoading {
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(.blue)
                        } else {
                            Button(action: register) {
                                HStack {
                                    Text("Create Account")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                    
                                    Image(systemName: "arrow.right")
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
                                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                                .scaleEffect(gradientAnimation ? 1.02 : 1.0)
                            }
                            .disabled(!isFormValid)
                            .opacity(isFormValid ? 1.0 : 0.6)
                            .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: gradientAnimation)
                        }
                        
                        Button("Already have an account? Sign In") {
                            dismiss()
                        }
                        .font(.subheadline)
                        .foregroundStyle(
                            LinearGradient(
                                colors: gradientAnimation ? [.blue, .purple] : [.purple, .pink],
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
        .navigationTitle("Register")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $profileImage)
        }
        .onChange(of: userName) { _ in validateForm() }
        .onChange(of: email) { _ in validateForm() }
        .onChange(of: displayName) { _ in validateForm() }
        .onChange(of: phoneNumber) { _ in validateForm() }
        .onChange(of: password) { _ in validateForm() }
        .onChange(of: confirmPassword) { _ in validateForm() }
        .accentColor(.blue)
    }
    
    private func register() {
        validateForm()
        guard isFormValid else { return }
        
        let imageData = profileImage?.jpegData(compressionQuality: 0.7)
        authViewModel.register(
            userName: userName,
            email: email,
            displayName: displayName,
            phoneNumber: phoneNumber,
            password: password,
            profilePicture: imageData
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
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
}

// MARK: - Animated Icon Text Field
struct AnimatedIconTextField: View {
    let title: String
    @Binding var text: String
    let icon: String
    let gradientColors: [Color]
    let isAnimating: Bool
    var keyboardType: UIKeyboardType = .default
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: isAnimating ? .top : .leading,
                            endPoint: isAnimating ? .bottom : .trailing
                        )
                    )
                    .frame(width: 20)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isAnimating)
                
                TextField("Enter your \(title.lowercased())", text: $text)
                    .textFieldStyle(PlainTextFieldStyle())
                    .keyboardType(keyboardType)
                    .textContentType(.none)
                    .autocapitalization(.none)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: [.gray.opacity(0.2), .gray.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
        }
    }
}

// MARK: - Animated Icon Secure Field
struct AnimatedIconSecureField: View {
    let title: String
    @Binding var text: String
    let icon: String
    let gradientColors: [Color]
    let isAnimating: Bool
    @Binding var isPasswordVisible: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: isAnimating ? .top : .leading,
                            endPoint: isAnimating ? .bottom : .trailing
                        )
                    )
                    .frame(width: 20)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isAnimating)
                
                if isPasswordVisible {
                    TextField("Enter your \(title.lowercased())", text: $text)
                        .textFieldStyle(PlainTextFieldStyle())
                } else {
                    SecureField("Enter your \(title.lowercased())", text: $text)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                
                Button {
                    isPasswordVisible.toggle()
                } label: {
                    Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.gray, .gray.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: [.gray.opacity(0.2), .gray.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
        }
    }
}

// MARK: - Fixed Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            
            guard let provider = results.first?.itemProvider else { return }
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, _ in
                    DispatchQueue.main.async {
                        self.parent.image = image as? UIImage
                    }
                }
            }
        }
    }
}

// MARK: - Preview
struct RegisterView_Previews: PreviewProvider {
    static var previews: some View {
        RegisterView()
            .environmentObject(AuthViewModel())
    }
}
