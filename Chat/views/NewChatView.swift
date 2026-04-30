import SwiftUI
/// View for creating a new private chat by selecting a user from the list

struct NewChatView: View {
    @ObservedObject var chatViewModel: ChatViewModel
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @State private var gradientAnimation = false
    private let primaryColor = Color(hex: "#7373d2")
    private let primaryColorLight = Color(hex: "#7373d2").opacity(0.2)
    private let iconGradientColors: [Color] = [Color(hex: "#7373d2"), Color(hex: "#9d73d2"), Color(hex: "#d273a3")]
    
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
    
    // Filter current user from the list
    var filteredUsers: [GetAllUsersDM] {
        let currentUserId = chatViewModel.getCurrentUserId()
        
        let users = chatViewModel.users.filter { user in
            return user.id != currentUserId
        }
        
        if searchText.isEmpty {
            return users
        } else {
            let searchTerm = searchText.lowercased()
            return users.filter { user in
                // Search in name (case insensitive)
                let nameMatch = user.name.lowercased().contains(searchTerm)
                
                // Search in phone number (remove formatting characters for better matching)
                let phoneDigits = user.phoneNumber.filter { $0.isNumber }
                let searchDigits = searchTerm.filter { $0.isNumber }
                
                // Check if phone number contains the search term
                let phoneMatch = user.phoneNumber.lowercased().contains(searchTerm) ||
                phoneDigits.contains(searchDigits)
                
                // Also check without country code or formatting
                let formattedPhone = formatPhoneNumber(user.phoneNumber)
                let formattedMatch = formattedPhone.lowercased().contains(searchTerm)
                
                // Return true if any field matches
                return nameMatch || phoneMatch || formattedMatch
            }
        }
    }
    
    // Helper function to format phone numbers for better searching
    private func formatPhoneNumber(_ phoneNumber: String) -> String {
        // Remove all non-digit characters
        let digits = phoneNumber.filter { $0.isNumber }
        
        // If number starts with country code, try to show without it
        if digits.hasPrefix("1") && digits.count >= 11 {
            // US/Canada format: remove country code 1
            return String(digits.dropFirst())
        } else if digits.hasPrefix("20") && digits.count >= 12 {
            // Egypt format: remove country code 20
            return String(digits.dropFirst(2))
        }
        
        return digits
    }
    
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
                
                if chatViewModel.isLoading && chatViewModel.users.isEmpty {
                    loadingView
                } else {
                    userListView
                }
                
            }
            .navigationTitle("New Chat")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
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
            .searchable(text: $searchText, prompt: "Search users...")
            .onAppear {
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                    gradientAnimation.toggle()
                }
                
                // Load users when view appears
                chatViewModel.loadAllUsers()
            }
            .alert("Error", isPresented: .constant(chatViewModel.errorMessage != nil)) {
                Button("OK", role: .cancel) {
                    chatViewModel.errorMessage = nil
                }
            } message: {
                Text(chatViewModel.errorMessage ?? "Unknown error")
            }
        }
        .accentColor(.blue)
    }
    
    private var loadingView: some View {
        VStack {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.blue)
                .padding()
            
            Text("Loading users...")
                .font(.subheadline)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
    }
    
    private var userListView: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                if filteredUsers.isEmpty && !searchText.isEmpty {
                    noResultsView
                } else if filteredUsers.isEmpty {
                    emptyStateView
                } else {
                    ForEach(filteredUsers) { user in
                        UserRow(
                            user: user,
                            hasExistingChat: chatViewModel.hasChatWithUser(userId: user.id),
                            gradientAnimation: gradientAnimation
                        ) {
                            handleUserSelection(user: user)
                        }
                        
                        Divider()
                            .padding(.leading, 68)
                    }
                }
            }
            .background(Color(.systemBackground).opacity(0.9))
        }
        .background(Color.clear)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "person.2")
                .font(.system(size: 60))
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
                Text("No Users Available")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [primaryColor, Color(hex: "#9d73d2")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("Try refreshing or check your connection")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button {
                chatViewModel.loadAllUsers()
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(.white)
                    
                    Text("Refresh Users")
                        .foregroundColor(.white)
                }
                .font(.headline)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [primaryColor, Color(hex: "#9d73d2")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(25)
                .shadow(color: primaryColor.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .padding(.top, 10)
            
            Spacer()
        }
        .frame(height: 400)
    }
    
    private var noResultsView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundStyle(
                    LinearGradient(
                        colors: iconGradientColors,
                        startPoint: gradientAnimation ? .topLeading : .bottomLeading,
                        endPoint: gradientAnimation ? .bottomTrailing : .topTrailing
                    )
                )
            
            Text("No users found")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("Try searching by name or phone number")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            
            Spacer()
        }
        .frame(height: 300)
        .padding()
    }
    
    private func handleUserSelection(user: GetAllUsersDM) {
        print("💬 Selected user: \(user.name) (ID: \(user.id))")
        
        // Check if already has chat with this user
        if chatViewModel.hasChatWithUser(userId: user.id) {
            print("⚠️ Already have chat with this user")
            // You might want to navigate to existing chat instead
            return
        }
        
        // Create new chat
        chatViewModel.createPrivateChat(with: user.id)
        isPresented = false
    }
}


import SwiftUI

// MARK: - UserRow View with Enhanced Debugging
struct UserRow: View {
    let user: GetAllUsersDM
    let hasExistingChat: Bool
    let gradientAnimation: Bool
    let onTap: () -> Void
    
    private let iconGradientColors: [Color] = [.blue, .purple, .pink]
    
    // ✅ ADD: State to track image loading
    @State private var imageLoadState: ImageLoadState = .loading
    
    enum ImageLoadState {
        case loading
        case success
        case failed(Error)
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Profile Image - with enhanced debugging
                profileImageView
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .lineLimit(1)
                    
                    Text(formatPhoneForDisplay(user.phoneNumber))
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    // ✅ IMPROVED: Debug indicator with more info
                    HStack(spacing: 4) {
                        Circle()
                            .fill(user.isDefaultImage ? Color.red : Color.green)
                            .frame(width: 6, height: 6)
                        
                        Text(debugText)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(user.isDefaultImage ? .red : .green)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(user.isDefaultImage ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
                    .cornerRadius(4)
                }
                
                Spacer()
                
                if hasExistingChat {
                    Image(systemName: "message.circle.fill")
                        .font(.title2)
                        .foregroundStyle(
                            LinearGradient(
                                colors: iconGradientColors,
                                startPoint: gradientAnimation ? .top : .leading,
                                endPoint: gradientAnimation ? .bottom : .trailing
                            )
                        )
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(
                            LinearGradient(
                                colors: iconGradientColors,
                                startPoint: gradientAnimation ? .top : .leading,
                                endPoint: gradientAnimation ? .bottom : .trailing
                            )
                        )
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color(.systemBackground))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // ✅ ADD: Debug text
    private var debugText: String {
        if user.isDefaultImage {
            return "Default"
        }
        
        switch imageLoadState {
        case .loading:
            return "Loading..."
        case .success:
            return "Custom ✓"
        case .failed:
            return "Failed ✗"
        }
    }
    
    @ViewBuilder
    private var profileImageView: some View {
        if user.isDefaultImage {
            // Show initials for default images
            defaultProfileView
        } else {
            // ✅ FIXED: Enhanced AsyncImage with better error tracking
            AsyncImage(url: URL(string: user.fullPictureUrl)) { phase in
                switch phase {
                case .empty:
                    loadingView
                        .onAppear {
                            imageLoadState = .loading
                            print("🔄 Loading image for \(user.name): \(user.fullPictureUrl)")
                        }
                        
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        )
                        .onAppear {
                            imageLoadState = .success
                            print("✅ Image loaded for \(user.name)")
                        }
                        
                case .failure(let error):
                    // ✅ FIXED: Show error info and fallback
                    defaultProfileView
                        .onAppear {
                            imageLoadState = .failed(error)
                            print("❌ Image load FAILED for \(user.name)")
                            print("   URL: \(user.fullPictureUrl)")
                            print("   Error: \(error.localizedDescription)")
                            
                            // ✅ Test if URL is reachable
                            testURLReachability(user.fullPictureUrl)
                        }
                        
                @unknown default:
                    defaultProfileView
                }
            }
        }
    }
    
    // ✅ Extracted default profile view
    private var defaultProfileView: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 50, height: 50)
            .overlay(
                Text(user.name.getInitials())
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            )
            .overlay(
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
    }
    
    private var loadingView: some View {
        Circle()
            .fill(Color.gray.opacity(0.2))
            .frame(width: 50, height: 50)
            .overlay(
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(.blue)
            )
            .overlay(
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
    }
    
    // ✅ Test URL reachability
    private func testURLReachability(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL format: \(urlString)")
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ Network error: \(error.localizedDescription)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 HTTP Status: \(httpResponse.statusCode)")
                print("📡 Content-Type: \(httpResponse.allHeaderFields["Content-Type"] ?? "unknown")")
                
                if httpResponse.statusCode != 200 {
                    print("❌ Server returned error code: \(httpResponse.statusCode)")
                }
            }
            
            if let data = data {
                print("📦 Received \(data.count) bytes")
            }
        }.resume()
    }
    
    private func formatPhoneForDisplay(_ phoneNumber: String) -> String {
        let digits = phoneNumber.filter { $0.isNumber }
        
        switch digits.count {
        case 10:
            let areaCode = String(digits.prefix(3))
            let prefix = String(digits.dropFirst(3).prefix(3))
            let lineNumber = String(digits.dropFirst(6))
            return "(\(areaCode)) \(prefix)-\(lineNumber)"
        case 11 where digits.hasPrefix("1"):
            let rest = String(digits.dropFirst())
            let areaCode = String(rest.prefix(3))
            let prefix = String(rest.dropFirst(3).prefix(3))
            let lineNumber = String(rest.dropFirst(6))
            return "+1 (\(areaCode)) \(prefix)-\(lineNumber)"
        default:
            return phoneNumber
        }
    }
}
