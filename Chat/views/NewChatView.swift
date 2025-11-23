import SwiftUI

struct NewChatView: View {
    @ObservedObject var chatViewModel: ChatViewModel
    @Binding var isPresented: Bool
    @State private var searchText = ""
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
    
    var filteredUsers: [APIUser] {
        if searchText.isEmpty {
            return chatViewModel.users
        } else {
            return chatViewModel.users.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
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
            .background(Color(.systemBackground).opacity(0.9))
        }
        .background(Color.clear)
    }
    
    private func handleUserSelection(user: APIUser) {
        chatViewModel.createPrivateChat(with: user.id)
        isPresented = false
    }
}

struct UserRow: View {
    let user: APIUser
    let hasExistingChat: Bool
    let gradientAnimation: Bool
    let onTap: () -> Void
    
    private let iconGradientColors: [Color] = [.blue, .purple, .pink]
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Profile Image
                AsyncImage(url: URL(string: user.fullPictureUrl)) { phase in
                    switch phase {
                    case .empty:
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
                    @unknown default:
                        EmptyView()
                    }
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
                    
                    if hasExistingChat {
                        Text("Chat exists")
                            .font(.system(size: 14))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
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
}
