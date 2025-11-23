import SwiftUI

struct ChatListView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var chatViewModel = ChatViewModel()
    @State private var showingNewChat = false
    @State private var showingProfile = false
    @State private var showingSearch = false
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
    
    var filteredChats: [Chat] {
        if searchText.isEmpty {
            return chatViewModel.chats
        } else {
            return chatViewModel.chats.filter { chat in
                chat.name.localizedCaseInsensitiveContains(searchText) ||
                chat.messages.last?.text.localizedCaseInsensitiveContains(searchText) == true
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
                .onAppear {
                    withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                        gradientAnimation.toggle()
                    }
                }
                
                if chatViewModel.chats.isEmpty {
                    emptyStateView
                } else {
                    chatListView
                }
            }
            .navigationTitle("Chats")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    profileButton
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        searchButton
                        newChatButton
                    }
                }
            }
            .searchable(text: $searchText, isPresented: $showingSearch, prompt: "Search chats...")
            .sheet(isPresented: $showingNewChat) {
                NewChatView(chatViewModel: chatViewModel, isPresented: $showingNewChat)
            }
            .sheet(isPresented: $showingProfile) {
                ProfileView(authViewModel: authViewModel, isPresented: $showingProfile)
            }
            .overlay {
                if chatViewModel.isLoading {
                    loadingOverlay
                }
            }
            .onAppear {
                print("📱 ChatListView appeared with \(chatViewModel.chats.count) chats")
            }
        }
        .accentColor(.green) // WhatsApp-like green accent
    }
    
    // MARK: - Subviews
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
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
                Text("No Chats Yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("Start chatting by tapping the compose button")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button {
                showingNewChat = true
                chatViewModel.loadAllUsers()
            } label: {
                HStack {
                    Image(systemName: "square.and.pencil")
                        .foregroundStyle(.white)
                    
                    Text("Start Chatting")
                        .foregroundColor(.white)
                }
                .font(.headline)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(25)
                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .padding(.top, 10)
        }
    }
    
    private var chatListView: some View {
           ScrollView {
               LazyVStack(spacing: 1) {
                   ForEach(filteredChats, id: \.id) { chat in
                       NavigationLink {
                           ChatDetailView(chat: chat, chatViewModel: chatViewModel)
                       } label: {
                           ChatRow(chat: chat, gradientAnimation: gradientAnimation)
                               .contentShape(Rectangle())
                       }
                       .buttonStyle(.plain)
                       
                       Divider()
                           .padding(.leading, 76)
                   }
               }
               .background(Color(.systemBackground).opacity(0.8))
           }
           .background(Color.clear)
       }
       
       private var profileButton: some View {
           Button {
               showingProfile = true
           } label: {
               ZStack {
                   Circle()
                       .fill(
                           LinearGradient(
                               colors: [.blue.opacity(0.1), .purple.opacity(0.1)],
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing
                           )
                       )
                       .frame(width: 36, height: 36)
                   
                   Image(systemName: "person.circle.fill")
                       .font(.title3)
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
       }
       
       private var searchButton: some View {
           Button {
               showingSearch = true
           } label: {
               ZStack {
                   Circle()
                       .fill(
                           LinearGradient(
                               colors: [.blue.opacity(0.1), .purple.opacity(0.1)],
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing
                           )
                       )
                       .frame(width: 36, height: 36)
                   
                   Image(systemName: "magnifyingglass")
                       .font(.title3)
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
       }
       
       private var newChatButton: some View {
           Button {
               if UserDefaults.standard.string(forKey: "authToken") != nil {
                   showingNewChat = true
                   chatViewModel.loadAllUsers()
               } else {
                   chatViewModel.errorMessage = "Not authenticated. Please login again."
               }
           } label: {
               ZStack {
                   Circle()
                       .fill(
                           LinearGradient(
                               colors: [.blue.opacity(0.1), .purple.opacity(0.1)],
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing
                           )
                       )
                       .frame(width: 36, height: 36)
                   
                   Image(systemName: "square.and.pencil")
                       .font(.title3)
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
       }
       
       private var loadingOverlay: some View {
           ZStack {
               Color.black.opacity(0.1)
                   .ignoresSafeArea()
               
               VStack(spacing: 16) {
                   ProgressView()
                       .scaleEffect(1.2)
                       .tint(.blue)
                   
                   Text("Loading...")
                       .font(.subheadline)
                       .foregroundStyle(
                           LinearGradient(
                               colors: [.blue, .purple],
                               startPoint: .leading,
                               endPoint: .trailing
                           )
                       )
               }
               .padding(24)
               .background(Color(.systemBackground))
               .cornerRadius(16)
               .shadow(color: .black.opacity(0.1), radius: 10)
           }
       }
   }

   // Enhanced ChatRow with moving gradient colors
   struct ChatRow: View {
       let chat: Chat
       let gradientAnimation: Bool
       
       private let iconGradientColors: [Color] = [.blue, .purple, .pink]
       
       private var lastMessageTime: String {
           guard let lastMessage = chat.messages.last else { return "" }
           return formatMessageTime(lastMessage.timestamp)
       }
       
       private var lastMessagePreview: String {
           return chat.messages.last?.text ?? "Say hello 👋"
       }
       
       var body: some View {
           HStack(spacing: 16) {
               // Profile Image with online indicator
               ZStack(alignment: .bottomTrailing) {
                   AsyncImage(url: URL(string: chat.fullPictureUrl)) { phase in
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
                               .frame(width: 56, height: 56)
                               .overlay(
                                   ProgressView()
                                       .scaleEffect(0.8)
                                       .tint(.blue)
                               )
                       case .success(let image):
                           image
                               .resizable()
                               .scaledToFill()
                               .frame(width: 56, height: 56)
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
                               .frame(width: 56, height: 56)
                               .overlay(
                                   Image(systemName: "person.fill")
                                       .font(.title2)
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
                   
                   // Online indicator
                   Circle()
                       .fill(Color.green)
                       .frame(width: 12, height: 12)
                       .overlay(
                           Circle()
                               .stroke(Color(.systemBackground), lineWidth: 2)
                       )
               }
               
               VStack(alignment: .leading, spacing: 4) {
                   HStack {
                       Text(chat.name)
                           .font(.system(size: 17, weight: .semibold))
                           .foregroundStyle(
                               LinearGradient(
                                   colors: [.blue, .purple],
                                   startPoint: .leading,
                                   endPoint: .trailing
                               )
                           )
                           .lineLimit(1)
                       
                       Spacer()
                       
                       Text(lastMessageTime)
                           .font(.system(size: 13))
                           .foregroundColor(.gray)
                   }
                   
                   HStack(alignment: .top, spacing: 4) {
                       Text(lastMessagePreview)
                           .font(.system(size: 15))
                           .foregroundColor(.secondary)
                           .lineLimit(2)
                       
                       Spacer()
                       
                       // Unread message badge
                       if hasUnreadMessages {
                           Circle()
                               .fill(
                                   LinearGradient(
                                       colors: [.blue, .purple],
                                       startPoint: .top,
                                       endPoint: .bottom
                                   )
                               )
                               .frame(width: 18, height: 18)
                               .overlay(
                                   Text("1")
                                       .font(.system(size: 12, weight: .semibold))
                                       .foregroundColor(.white)
                               )
                       }
                   }
               }
           }
           .padding(.vertical, 12)
           .padding(.horizontal, 16)
           .background(Color(.systemBackground).opacity(0.9))
           .contentShape(Rectangle())
       }
    
    private var hasUnreadMessages: Bool {
        // Implement your unread message logic here
        return false
    }
    
    private func formatMessageTime(_ timestamp: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        
        guard let date = formatter.date(from: timestamp) else {
            return timestamp
        }
        
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            formatter.dateFormat = "dd/MM/yy"
            return formatter.string(from: date)
        }
    }
}
