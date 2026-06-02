import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var userName = ""
    @State private var password = ""
    @State private var isPasswordVisible = false
    @State private var gradientAnimation = false
    @State private var showingSavedAccounts = false
    @Environment(\.dismiss) private var dismiss
    @State private var isAuthenticating = false

    // Define the main color as static computed properties - SAME AS ProfileView
    private var primaryColor: Color { Color(hex: "#7373d2") }
    private var primaryColorLight: Color { primaryColor.opacity(0.2) }
    private var primaryColorDark: Color { primaryColor.opacity(0.8) }
    
    // Computed gradient colors - SAME AS ProfileView
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
    
    // Dark purple gradient (same as ProfileView)
    private var darkPurpleGradient: [Color] {
        [Color(hex: "#5a5aa8"), primaryColor] // Darker purple to primary purple
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
                .onAppear {
                    withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                        gradientAnimation.toggle()
                    }
                }
                
                VStack(spacing: 32) {
                    VStack(spacing: 16) {
                        // Check what type of image it is
                            // Custom image asset
                            Image("JawabiLogo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 120, height: 120) // Square aspect
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .shadow(color: primaryColor.opacity(0.3), radius: 10, x: 0, y: 5)
                        
                        
                        VStack(spacing: 8) {
                            Text("Welcome Back")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: darkPurpleGradient,
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
                    // Saved Accounts Section (NEW)
                                       if !authViewModel.savedAccounts.isEmpty {
                                           SavedAccountsSection()
                                               .transition(.opacity)
                                       }
                                       
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
                                                               colors: darkPurpleGradient,
                                                               startPoint: .leading,
                                                               endPoint: .trailing
                                                           )
                                                       )
                                                       .frame(width: 20)
                                                   
                                                   TextField("Enter your username", text: $userName)
                                                       .textFieldStyle(PlainTextFieldStyle())
                                                       .autocapitalization(.none)
                                                       .disableAutocorrection(true)
                                                   
                                                   // Auto-fill button for saved accounts
                                                   if !authViewModel.savedAccounts.contains(userName) && !userName.isEmpty {
                                                       Button {
                                                           if let credentials = authViewModel.autoFillCredentials(for: userName) {
                                                               self.password = credentials.password
                                                           }
                                                       } label: {
                                                           Image(systemName: "key.fill")
                                                               .foregroundStyle(
                                                                   LinearGradient(
                                                                       colors: darkPurpleGradient,
                                                                       startPoint: .leading,
                                                                       endPoint: .trailing
                                                                   )
                                                               )
                                                       }
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
                                            colors: darkPurpleGradient,
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: 20)
                                
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
                                                colors: darkPurpleGradient,
                                                startPoint: .leading,
                                                endPoint: .trailing
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
                    .padding(.horizontal)
                    
                    // Login Button - DARK PURPLE GRADIENT (STATIC)
                    VStack(spacing: 16) {
                        if authViewModel.isLoading {
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(primaryColor)
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
                                        colors: darkPurpleGradient,
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                                .shadow(color: primaryColor.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            .disabled(userName.isEmpty || password.isEmpty)
                            .opacity((userName.isEmpty || password.isEmpty) ? 0.6 : 1.0)
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
                                            colors: darkPurpleGradient,
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
                    
                    Spacer()
                }
            }
            // Your existing view code
                   .onChange(of: authViewModel.isAuthenticated) { isAuthenticated in
                       if isAuthenticated && isAuthenticating {
                           dismiss()
                       }
                   }
                   .onChange(of: authViewModel.isLoading) { isLoading in
                       isAuthenticating = isLoading
                   }
            
            .navigationBarHidden(true)
            .onAppear {
                           // Load saved accounts when view appears
                           authViewModel.loadSavedAccounts()
                           
                           // Auto-fill last used account if available
                           if let lastUsername = UserDefaults.standard.string(forKey: "lastUsername") {
                               userName = lastUsername
                               if let credentials = authViewModel.autoFillCredentials(for: lastUsername) {
                                   password = credentials.password
                               }
                           }
                       }
        }
        .accentColor(primaryColor)
    }
    
       // MARK: - Saved Accounts Section
       @ViewBuilder
       private func SavedAccountsSection() -> some View {
           VStack(alignment: .leading, spacing: 12) {
               HStack {
                   Image(systemName: "person.crop.circle.badge.clock")
                       .foregroundStyle(
                           LinearGradient(
                               colors: darkPurpleGradient,
                               startPoint: .leading,
                               endPoint: .trailing
                           )
                       )
                   
                   Text("Saved Accounts")
                       .font(.headline)
                       .foregroundStyle(
                           LinearGradient(
                               colors: darkPurpleGradient,
                               startPoint: .leading,
                               endPoint: .trailing
                           )
                       )
                   
                   Spacer()
                   
                   Button {
                       showingSavedAccounts.toggle()
                   } label: {
                       Image(systemName: "chevron.down")
                           .rotationEffect(.degrees(showingSavedAccounts ? 180 : 0))
                   }
                   .foregroundColor(.secondary)
               }
               
               if showingSavedAccounts {
                   VStack(spacing: 8) {
                       ForEach(authViewModel.savedAccounts, id: \.self) { username in
                           SavedAccountRow(username: username)
                       }
                   }
                   .transition(.opacity.combined(with: .move(edge: .top)))
               }
           }
           .padding()
           .background(
               RoundedRectangle(cornerRadius: 12)
                   .fill(Color(.systemBackground))
                   .shadow(color: .gray.opacity(0.1), radius: 5, x: 0, y: 2)
           )
           .padding(.horizontal)
       }
       
       // MARK: - Saved Account Row
       private func SavedAccountRow(username: String) -> some View {
           Button {
               // Auto-fill this account
               userName = username
               if let credentials = authViewModel.autoFillCredentials(for: username) {
                   password = credentials.password
               }
           } label: {
               HStack {
                   Image(systemName: "person.circle.fill")
                       .font(.title2)
                       .foregroundStyle(
                           LinearGradient(
                               colors: darkPurpleGradient,
                               startPoint: .leading,
                               endPoint: .trailing
                           )
                       )
                   
                   VStack(alignment: .leading, spacing: 2) {
                       Text(username)
                           .font(.subheadline)
                           .fontWeight(.medium)
                           .foregroundColor(.primary)
                       
                       Text("Tap to auto-fill")
                           .font(.caption)
                           .foregroundColor(.secondary)
                   }
                   
                   Spacer()
                   
                   // Delete button
                   Button {
                       authViewModel.deleteSavedAccount(username)
                   } label: {
                       Image(systemName: "trash")
                           .font(.caption)
                           .foregroundColor(.red)
                   }
                   .buttonStyle(.plain)
               }
               .padding(.vertical, 8)
               .padding(.horizontal, 12)
               .background(Color.gray.opacity(0.05))
               .cornerRadius(8)
           }
           .buttonStyle(.plain)
       }
   }

// MARK: - Preview
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(AuthViewModel())
    }
}
