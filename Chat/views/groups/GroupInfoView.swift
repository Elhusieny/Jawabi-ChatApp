//
//  GroupInfoView.swift
//  Chat
//
//  Created by Ahmed Elhussieny on 12/05/2026.
//


//
//  GroupInfoView.swift
//  Chat
//
//  Created by Your Name on 12/05/2026.
//

import SwiftUI

struct GroupInfoView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var chatViewModel: ChatViewModel
    let chat: Chat
    
    @State private var showingAddMembers = false
    @State private var members: [GroupMemberInfo] = []
    @State private var isLoading = false
    
    private var currentUserId: String {
        UserDefaults.standard.string(forKey: "currentUserId") ?? ""
    }
    
    var body: some View {
        List {
            // Group Header
            Section {
                VStack(spacing: 12) {
                    // Group Avatar
                    if chat.pictureUrl.isEmpty == false && !(chat.pictureUrl.contains("default.png") ?? true) {
                        AsyncImage(url: URL(string: chat.fullPictureUrl)) { image in
                            image.resizable()
                                .scaledToFill()
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 100, height: 100)
                            .overlay(
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.blue)
                            )
                    }
                    
                    Text(chat.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("\(chat.users.count) members")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
                .listRowBackground(Color.clear)
            }
            
            // Admin Actions (only for admins)
            if chat.isCurrentUserAdmin {
                Section("Group Actions") {
                    Button(action: {
                        showingAddMembers = true
                    }) {
                        HStack {
                            Image(systemName: "person.badge.plus")
                                .foregroundColor(.blue)
                            Text("Add Members")
                                .foregroundColor(.primary)
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
            
            // Leave Group
            Section {
                Button(action: {
                    leaveGroup()
                }) {
                    HStack {
                        Spacer()
                        Text("Leave Group")
                            .foregroundColor(.red)
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Group Info")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddMembers) {
            AddMembersView(
                chatId: chat.id,
                chatName: chat.name,
                existingMembers: members.map { $0.id }
            )
        }
        .onAppear {
            loadMembers()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ChatMembersUpdated"))) { notification in
            if let chatId = notification.userInfo?["chatId"] as? Int, chatId == chat.id {
                loadMembers()
                refreshGroupInfo()
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
    
    private func makeAdmin(_ member: GroupMemberInfo) {
        // Implement make admin API call
        print("Making \(member.name) admin")
    }
    
    private func removeAdmin(_ member: GroupMemberInfo) {
        // Implement remove admin API call
        print("Removing admin from \(member.name)")
    }
    
    private func removeMember(_ member: GroupMemberInfo) {
        // Implement remove member API call
        print("Removing member \(member.name)")
    }
    
    private func leaveGroup() {
        // Implement leave group API call
        print("Leaving group: \(chat.name)")
        dismiss()
    }
    
    private func refreshGroupInfo() {
        chatViewModel.loadChat(chatId: chat.id)
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
