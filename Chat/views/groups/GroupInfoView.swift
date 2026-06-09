import SwiftUI

struct GroupInfoView: View {
    @ObservedObject var chatViewModel: ChatViewModel
    let chat: Chat
    @Environment(\.dismiss) var dismiss
    @State private var showingMemberList = false
    @State private var members: [GroupMemberInfo] = []
    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    private var currentUserId: String {
        UserDefaults.standard.string(forKey: "currentUserId") ?? ""
    }
    
    var body: some View {
        List {
            // Group Header
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        // Group Avatar
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                            
                            if chat.pictureUrl.isEmpty == false && !(chat.pictureUrl.contains("default.png") ?? true) {
                                AsyncImage(url: URL(string: chat.fullPictureUrl)) { phase in
                                    if let image = phase.image {
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 80, height: 80)
                                            .clipShape(Circle())
                                    } else {
                                        Image(systemName: "person.2.fill")
                                            .font(.system(size: 40))
                                            .foregroundColor(.gray)
                                    }
                                }
                            } else {
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Text(chat.name)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("\(chat.users.count) members")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 12)
            }
            .listRowBackground(Color.clear)
            
            // Admin Actions (only for admins)
            if chat.isCurrentUserAdmin {
                Section("Group Actions") {
                    Button(action: {
                        showingMemberList = true
                    }) {
                        HStack {
                            Label("Manage Members", systemImage: "person.badge.plus")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // Members Section
            Section("Members") {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else {
                    ForEach(members) { member in
                        MemberInfoRow(
                            member: member,
                            isCurrentUser: member.id == currentUserId,
                            isCurrentUserAdmin: chat.isCurrentUserAdmin,
                            onMakeAdmin: { makeAdmin(member) },
                            onRemoveAdmin: { removeAdmin(member) },
                            onRemoveMember: { removeMember(member) }
                        )
                    }
                }
            }
            
            // Media, Files, etc. (Optional)
            Section {
                Button {
                    // Show shared media
                } label: {
                    Label("Shared Media", systemImage: "photo.on.rectangle")
                }
                
                Button {
                    // Show shared files
                } label: {
                    Label("Shared Files", systemImage: "doc")
                }
            }
            
            // Leave Group Button
            Section {
                LeaveChatButton(
                    chatId: chat.id,
                    chatName: chat.name,
                    chatType: chat.type,
                    chatViewModel: chatViewModel
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Group Info")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingMemberList) {
            EnhancedMemberListView(
                chat: chat,
                chatViewModel: chatViewModel,
                onMembersUpdated: {
                    loadMembers()
                    refreshGroupInfo()
                }
            )
        }
        .onAppear {
            loadMembers()
            setupNotificationObservers()
        }
        .onDisappear {
            removeNotificationObservers()
        }
        .alert("Message", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ChatMembersUpdated"))) { notification in
            if let chatId = notification.userInfo?["chatId"] as? Int, chatId == chat.id {
                loadMembers()
                refreshGroupInfo()
            }
        }
    }
    
    // MARK: - Member Loading
    
    private func loadMembers() {
        isLoading = true
        members = chat.users.map { user in
            GroupMemberInfo(
                id: user.userId,
                name: getUserName(from: user.userId),
                role: user.role,
                isOnline: chatViewModel.userStatuses[user.userId] ?? false
            )
        }
        .sorted { $0.role < $1.role } // Admins first
        isLoading = false
    }
    
    private func getUserName(from userId: String) -> String {
        // Find user in cached users
        if let user = chatViewModel.users.first(where: { $0.id == userId }) {
            return user.name
        }
        
        // Check if it's current user
        if userId == currentUserId {
            return "You"
        }
        
        // Return ID prefix as fallback
        return String(userId.prefix(8))
    }
    
    // MARK: - Admin Management
    
    private func makeAdmin(_ member: GroupMemberInfo) {
        isLoading = true
        
        AdminManagementService.shared.promoteToAdmin(chatId: chat.id, targetUserId: member.id)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                self.isLoading = false
                
                if case .failure(let error) = completion {
                    self.alertMessage = "Failed to promote \(member.name) to admin: \(error.localizedDescription)"
                    self.showingAlert = true
                    print("❌ Error promoting admin: \(error)")
                }
            }, receiveValue: {
                print("✅ Successfully promoted \(member.name) to admin")
                self.alertMessage = "\(member.name) is now an admin"
                self.showingAlert = true
                self.loadMembers()
                self.refreshGroupInfo()
            })
            .store(in: &chatViewModel.cancellables)
    }
    
    private func removeAdmin(_ member: GroupMemberInfo) {
        isLoading = true
        
        AdminManagementService.shared.removeAdmin(chatId: chat.id, targetUserId: member.id)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                self.isLoading = false
                
                if case .failure(let error) = completion {
                    self.alertMessage = "Failed to remove admin from \(member.name): \(error.localizedDescription)"
                    self.showingAlert = true
                    print("❌ Error removing admin: \(error)")
                }
            }, receiveValue: {
                print("✅ Successfully removed admin from \(member.name)")
                self.alertMessage = "\(member.name) is no longer an admin"
                self.showingAlert = true
                self.loadMembers()
                self.refreshGroupInfo()
            })
            .store(in: &chatViewModel.cancellables)
    }
    
    private func removeMember(_ member: GroupMemberInfo) {
        isLoading = true
        
        AdminManagementService.shared.removeMember(chatId: chat.id, targetUserId: member.id)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                self.isLoading = false
                
                if case .failure(let error) = completion {
                    self.alertMessage = "Failed to remove \(member.name): \(error.localizedDescription)"
                    self.showingAlert = true
                    print("❌ Error removing member: \(error)")
                }
            }, receiveValue: {
                print("✅ Successfully removed \(member.name) from group")
                self.alertMessage = "\(member.name) has been removed from the group"
                self.showingAlert = true
                self.loadMembers()
                self.refreshGroupInfo()
            })
            .store(in: &chatViewModel.cancellables)
    }
    
    private func refreshGroupInfo() {
        chatViewModel.loadChat(chatId: chat.id)
    }
    
    // MARK: - Notification Observers
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("UserPromoted"),
            object: nil,
            queue: .main
        ) { notification in
            if let chatId = notification.userInfo?["chatId"] as? Int,
               chatId == self.chat.id {
                self.loadMembers()
                self.refreshGroupInfo()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("AdminRemoved"),
            object: nil,
            queue: .main
        ) { notification in
            if let chatId = notification.userInfo?["chatId"] as? Int,
               chatId == self.chat.id {
                self.loadMembers()
                self.refreshGroupInfo()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("MemberRemoved"),
            object: nil,
            queue: .main
        ) { notification in
            if let chatId = notification.userInfo?["chatId"] as? Int,
               chatId == self.chat.id {
                self.loadMembers()
                self.refreshGroupInfo()
            }
        }
    }
    
    private func removeNotificationObservers() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("UserPromoted"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("AdminRemoved"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("MemberRemoved"), object: nil)
    }
}

// MARK: - Enhanced Member List View
struct EnhancedMemberListView: View {
    let chat: Chat
    @ObservedObject var chatViewModel: ChatViewModel
    let onMembersUpdated: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var members: [GroupMemberInfo] = []
    @State private var isLoading = false
    
    private var currentUserId: String {
        UserDefaults.standard.string(forKey: "currentUserId") ?? ""
    }
    
    var filteredMembers: [GroupMemberInfo] {
        if searchText.isEmpty {
            return members
        } else {
            return members.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationView {
            List(filteredMembers) { member in
                MemberInfoRow(
                    member: member,
                    isCurrentUser: member.id == currentUserId,
                    isCurrentUserAdmin: chat.isCurrentUserAdmin,
                    onMakeAdmin: { makeAdmin(member) },
                    onRemoveAdmin: { removeAdmin(member) },
                    onRemoveMember: { removeMember(member) }
                )
            }
            .searchable(text: $searchText, prompt: "Search members")
            .navigationTitle("Members (\(members.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadMembers()
            }
        }
    }
    
    private func loadMembers() {
        isLoading = true
        members = chat.users.map { user in
            GroupMemberInfo(
                id: user.userId,
                name: getUserName(from: user.userId),
                role: user.role,
                isOnline: chatViewModel.userStatuses[user.userId] ?? false
            )
        }
        .sorted { $0.role < $1.role }
        isLoading = false
    }
    
    private func getUserName(from userId: String) -> String {
        if let user = chatViewModel.users.first(where: { $0.id == userId }) {
            return user.name
        }
        if userId == currentUserId {
            return "You"
        }
        return String(userId.prefix(8))
    }
    
    private func makeAdmin(_ member: GroupMemberInfo) {
        AdminManagementService.shared.promoteToAdmin(chatId: chat.id, targetUserId: member.id)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("❌ Error promoting admin: \(error)")
                }
            }, receiveValue: {
                self.onMembersUpdated()
                self.loadMembers()
            })
            .store(in: &chatViewModel.cancellables)
    }
    
    private func removeAdmin(_ member: GroupMemberInfo) {
        AdminManagementService.shared.removeAdmin(chatId: chat.id, targetUserId: member.id)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("❌ Error removing admin: \(error)")
                }
            }, receiveValue: {
                self.onMembersUpdated()
                self.loadMembers()
            })
            .store(in: &chatViewModel.cancellables)
    }
    
    private func removeMember(_ member: GroupMemberInfo) {
        AdminManagementService.shared.removeMember(chatId: chat.id, targetUserId: member.id)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("❌ Error removing member: \(error)")
                }
            }, receiveValue: {
                self.onMembersUpdated()
                self.loadMembers()
            })
            .store(in: &chatViewModel.cancellables)
    }
}

// MARK: - Models
struct GroupMemberInfo: Identifiable {
    let id: String
    let name: String
    let role: Int // 0 = admin, 1 = member
    let isOnline: Bool
}

// MARK: - Member Row
struct MemberInfoRow: View {
    let member: GroupMemberInfo
    let isCurrentUser: Bool
    let isCurrentUserAdmin: Bool
    let onMakeAdmin: () -> Void
    let onRemoveAdmin: () -> Void
    let onRemoveMember: () -> Void
    
    @State private var showingActionSheet = false
    
    var body: some View {
        HStack {
            // Avatar
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(member.name.prefix(1).uppercased())
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                )
                .overlay(
                    Circle()
                        .stroke(member.isOnline ? Color.green : Color.gray.opacity(0.3), lineWidth: 2)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(member.name)
                        .font(.body)
                        .fontWeight(.medium)
                    
                    if isCurrentUser {
                        Text("(You)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if member.role == 0 {
                        Text("Admin")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .cornerRadius(4)
                    }
                }
                
                Text(member.isOnline ? "Online" : "Offline")
                    .font(.caption)
                    .foregroundColor(member.isOnline ? .green : .secondary)
            }
            
            Spacer()
            
            // Admin controls
            if isCurrentUserAdmin && !isCurrentUser {
                Button(action: {
                    showingActionSheet = true
                }) {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.secondary)
                }
                .actionSheet(isPresented: $showingActionSheet) {
                    ActionSheet(
                        title: Text("Manage \(member.name)"),
                        message: nil,
                        buttons: [
                            .default(member.role == 1 ? Text("Make Admin") : Text("Remove Admin")) {
                                if member.role == 1 {
                                    onMakeAdmin()
                                } else {
                                    onRemoveAdmin()
                                }
                            },
                            .destructive(Text("Remove from Group")) {
                                onRemoveMember()
                            },
                            .cancel()
                        ]
                    )
                }
            }
        }
        .padding(.vertical, 4)
    }
}
