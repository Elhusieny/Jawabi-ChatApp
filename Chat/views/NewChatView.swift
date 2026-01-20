import SwiftUI

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
    
    
    var filteredUsers: [GetAllUsersDM] {
        if searchText.isEmpty {
            return chatViewModel.users
        } else {
            let searchTerm = searchText.lowercased()
            return chatViewModel.users.filter { user in
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
    
    private var noResultsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.slash")
                .font(.system(size: 50))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Text("No users found")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("Try searching by name or phone number")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(height: 200)
        .padding()
    }
    
    private func handleUserSelection(user: GetAllUsersDM) {
        chatViewModel.createPrivateChat(with: user.id)
        isPresented = false
    }
    
    
}

struct UserRow: View {
    let user: GetAllUsersDM
    let hasExistingChat: Bool
    let gradientAnimation: Bool
    let onTap: () -> Void
    
    private let iconGradientColors: [Color] = [.blue, .purple, .pink]
    
    // Add debug for image URL
    init(user: GetAllUsersDM, hasExistingChat: Bool, gradientAnimation: Bool, onTap: @escaping () -> Void) {
        self.user = user
        self.hasExistingChat = hasExistingChat
        self.gradientAnimation = gradientAnimation
        self.onTap = onTap
        
        // Debug the image URL
        print("\n🖼️ UserRow for \(user.name):")
        print("   Original pictureUrl: \(user.pictureUrl)")
        print("   Full pictureUrl: \(user.fullPictureUrl)")
        print("   Has existing chat: \(hasExistingChat)")
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Profile Image - UPDATED with better handling
                if user.fullPictureUrl.isEmpty {
                    // Show placeholder for default or empty images
                    placeholderCircle
                } else if let url = URL(string: user.fullPictureUrl) {
                    // Load actual image
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            placeholderCircle
                                .overlay(
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(.blue)
                                )
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
                        case .failure:
                            placeholderCircle
                        @unknown default:
                            placeholderCircle
                        }
                    }
                } else {
                    // Invalid URL
                    placeholderCircle
                }
                
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
                    
                    // Display phone number under the name
                    Text(formatPhoneForDisplay(user.phoneNumber))
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    if hasExistingChat {
                        Text("Chat exists")
                            .font(.system(size: 13))
                            .foregroundStyle(.blue.opacity(0.8))
                    }
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
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: gradientAnimation)
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
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: gradientAnimation)
                }
            }
            .padding()
            .background(Color(.systemBackground).opacity(0.9))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private var placeholderCircle: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 50, height: 50)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: iconGradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
    }
    
    // Helper function to format phone number for display
    private func formatPhoneForDisplay(_ phoneNumber: String) -> String {
        // Remove all non-digit characters
        let digits = phoneNumber.filter { $0.isNumber }
        
        // Format based on length
        switch digits.count {
        case 10:
            // Format as (XXX) XXX-XXXX
            let areaCode = String(digits.prefix(3))
            let prefix = String(digits.dropFirst(3).prefix(3))
            let lineNumber = String(digits.dropFirst(6))
            return "(\(areaCode)) \(prefix)-\(lineNumber)"
        case 11 where digits.hasPrefix("1"):
            // US/Canada with country code
            let rest = String(digits.dropFirst())
            let areaCode = String(rest.prefix(3))
            let prefix = String(rest.dropFirst(3).prefix(3))
            let lineNumber = String(rest.dropFirst(6))
            return "+1 (\(areaCode)) \(prefix)-\(lineNumber)"
        default:
            // Return original if not standard format
            return phoneNumber
        }
    }
}
