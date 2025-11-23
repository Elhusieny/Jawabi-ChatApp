import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var userName = ""
    @State private var password = ""
    @State private var isPasswordVisible = false
    
    @State private var gradientAnimation = false

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
    
    // Consistent icon gradient colors for all icons
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
                .onAppear {
                    withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                        gradientAnimation.toggle()
                    }
                }
                
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "message.circle.fill")
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
                        
                        VStack(spacing: 8) {
                            Text("Welcome Back")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            
                            Text("Sign in to continue your conversations")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top, 40)
                    
                    // Form
                    VStack(spacing: 20) {
                        // Username Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Username")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            HStack {
                                Image(systemName: "person.fill")
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: iconGradientColors,
                                            startPoint: gradientAnimation ? .top : .leading,
                                            endPoint: gradientAnimation ? .bottom : .trailing
                                        )
                                    )
                                    .frame(width: 20)
                                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: gradientAnimation)
                                
                                TextField("Enter your username", text: $userName)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                        }
                        
                        // Password Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            HStack {
                                Image(systemName: "lock.fill")
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: iconGradientColors,
                                            startPoint: gradientAnimation ? .top : .leading,
                                            endPoint: gradientAnimation ? .bottom : .trailing
                                        )
                                    )
                                    .frame(width: 20)
                                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: gradientAnimation)
                                
                                if isPasswordVisible {
                                    TextField("Enter your password", text: $password)
                                        .textFieldStyle(PlainTextFieldStyle())
                                } else {
                                    SecureField("Enter your password", text: $password)
                                        .textFieldStyle(PlainTextFieldStyle())
                                }
                                
                                Button {
                                    isPasswordVisible.toggle()
                                } label: {
                                    Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: iconGradientColors,
                                                startPoint: gradientAnimation ? .top : .leading,
                                                endPoint: gradientAnimation ? .bottom : .trailing
                                            )
                                        )
                                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: gradientAnimation)
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    // Login Button
                    VStack(spacing: 16) {
                        if authViewModel.isLoading {
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(.blue)
                        } else {
                            Button {
                                authViewModel.login(userName: userName, password: password)
                            } label: {
                                HStack {
                                    Text("Sign In")
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
                            .disabled(userName.isEmpty || password.isEmpty)
                            .opacity((userName.isEmpty || password.isEmpty) ? 0.6 : 1.0)
                            .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: gradientAnimation)
                        }
                        
                        // Register Link
                        NavigationLink {
                            RegisterView()
                        } label: {
                            HStack {
                                Text("Don't have an account?")
                                    .foregroundColor(.secondary)
                                
                                Text("Register")
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.blue, .purple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .fontWeight(.semibold)
                            }
                            .font(.subheadline)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Error Message
                    if let error = authViewModel.errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.orange, .red],
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
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
        .accentColor(.blue)
    }
}
