import SwiftUI

struct ConnectToOrganizationView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State Variables
    @State private var serverURL = ""
    @State private var userName = ""
    @State private var password = ""
    @State private var isPasswordVisible = false
    @State private var isConnecting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var connectionStatus: ConnectionStatus = .idle
    @State private var gradientAnimation = false
    
    // MARK: - Colors (Same as LoginView)
    private var primaryColor: Color { Color(hex: "#7373d2") }
    private var darkPurpleGradient: [Color] {
        [Color(hex: "#5a5aa8"), primaryColor]
    }
    
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
    
    private enum ConnectionStatus {
        case idle
        case testing
        case success
        case failure
        
        var color: Color {
            switch self {
            case .idle: return .gray
            case .testing: return .orange
            case .success: return .green
            case .failure: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .idle: return "network.slash"
            case .testing: return "arrow.triangle.2.circlepath"
            case .success: return "checkmark.circle.fill"
            case .failure: return "xmark.circle.fill"
            }
        }
        
        var message: String {
            switch self {
            case .idle: return "Enter your organization server details"
            case .testing: return "Testing connection..."
            case .success: return "Connected successfully!"
            case .failure: return "Connection failed"
            }
        }
    }
    
    // MARK: - Body
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
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Header
                        headerView
                        
                        // Organization Info Card
                        organizationInfoCard
                        
                        // Connection Form
                        connectionForm
                        
                        // Status Section
                        statusSection
                        
                        // Connect Button
                        connectButton
                        
                        // Back to Login
                        backToLoginButton
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                }
            }
            .navigationBarHidden(true)
            .alert("Connection Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .onChange(of: authViewModel.isAuthenticated) { isAuthenticated in
                if isAuthenticated && isConnecting {
                    connectionStatus = .success
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 12) {
            Image(systemName: "building.2.crop.circle")
                .font(.system(size: 70))
                .foregroundStyle(
                    LinearGradient(
                        colors: darkPurpleGradient,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .background(
                    Circle()
                        .fill(primaryColor.opacity(0.1))
                        .frame(width: 120, height: 120)
                )
            
            Text("Connect to Organization")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(
                    LinearGradient(
                        colors: darkPurpleGradient,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Text("Enter your company's server details to connect")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }
    
    // MARK: - Organization Info Card
    private var organizationInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(primaryColor)
                Text("Organization Settings")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            Text("Enter your organization's server URL to enable offline/on-premise mode. This allows you to connect to your company's private server.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            HStack {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(.green)
                    .font(.caption)
                Text("Your data stays within your organization's network")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .gray.opacity(0.08), radius: 5, x: 0, y: 2)
        )
    }
    
    // MARK: - Connection Form
    private var connectionForm: some View {
        VStack(spacing: 16) {
            // Server URL Field
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Server URL")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button {
                        // Reset to primary server
                        serverURL = ServerConfigManager.shared.primaryServerURL
                    } label: {
                        Text("Use Default")
                            .font(.caption)
                            .foregroundColor(primaryColor)
                    }
                }
                
                HStack {
                    Image(systemName: "globe")
                        .foregroundStyle(
                            LinearGradient(
                                colors: darkPurpleGradient,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 20)
                    
                    TextField("e.g., http://company-server.com:8444", text: $serverURL)
                        .textFieldStyle(PlainTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            connectionStatus == .failure ? Color.red.opacity(0.3) :
                            connectionStatus == .success ? Color.green.opacity(0.3) :
                            Color.gray.opacity(0.2),
                            lineWidth: 1
                        )
                )
            }
            
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
                    
                    TextField("Enter your company username", text: $userName)
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
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }
    
    // MARK: - Status Section
    private var statusSection: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: connectionStatus.icon)
                    .foregroundColor(connectionStatus.color)
                    .font(.title3)
                
                Text(connectionStatus.message)
                    .font(.subheadline)
                    .foregroundColor(connectionStatus.color == .idle ? .secondary : connectionStatus.color)
                
                Spacer()
                
                if connectionStatus == .testing {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(connectionStatus.color)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(connectionStatus.color.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(connectionStatus.color.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
    
    // MARK: - Connect Button
    private var connectButton: some View {
        Button {
            connectToOrganization()
        } label: {
            HStack {
                if isConnecting {
                    ProgressView()
                        .tint(.white)
                        .padding(.trailing, 8)
                }
                
                Text(isConnecting ? "Connecting..." : "Connect to Organization")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: isFormValid ? darkPurpleGradient : [Color.gray.opacity(0.5), Color.gray.opacity(0.3)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(color: primaryColor.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .disabled(!isFormValid || isConnecting)
        .opacity(isFormValid ? 1.0 : 0.6)
    }
    
    // MARK: - Back to Login Button
    private var backToLoginButton: some View {
        Button {
            dismiss()
        } label: {
            HStack {
                Image(systemName: "arrow.left")
                Text("Back to Login")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Computed Properties
    private var isFormValid: Bool {
        !serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.isEmpty
    }
    
    // MARK: - Methods
    private func connectToOrganization() {
        guard isFormValid else { return }
        
        isConnecting = true
        connectionStatus = .testing
        errorMessage = ""
        showError = false
        
        let trimmedServerURL = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUsername = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Set the active server URL
        ServerConfigManager.shared.activeServerURL = trimmedServerURL
        
        // Save the server URL for this account
        authViewModel.saveServerURL(trimmedServerURL, for: trimmedUsername)
        
        // Save last used username
        UserDefaults.standard.set(trimmedUsername, forKey: "lastUsername")
        
        // Perform login with the custom server
        authViewModel.login(userName: trimmedUsername, password: password)
        
        // Set a timeout for connection
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            if self.isConnecting && !self.authViewModel.isAuthenticated {
                self.isConnecting = false
                self.connectionStatus = .failure
                self.errorMessage = "Connection timeout. Please check the server URL and try again."
                self.showError = true
            }
        }
    }
}

// MARK: - Preview
struct ConnectToOrganizationView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectToOrganizationView()
            .environmentObject(AuthViewModel())
    }
}