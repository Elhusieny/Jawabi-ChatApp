//
//  AddMembersView.swift
//  Chat
//
//  Created by Ahmed Elhussieny on 12/05/2026.
//


// AddMembersView.swift
import SwiftUI

struct AddMembersView: View {
    // MARK: - Properties
    @State private var searchText = ""
    
    let chatId: Int
        let chatName: String
        let existingMembers: [String]
        
        @StateObject private var viewModel: AddMembersViewModel
        @Environment(\.dismiss) var dismiss
        
        init(chatId: Int, chatName: String, existingMembers: [String]) {
            self.chatId = chatId
            self.chatName = chatName
            self.existingMembers = existingMembers
            _viewModel = StateObject(wrappedValue: AddMembersViewModel(
                chatId: chatId,
                existingMembers: existingMembers
            ))
        }
    // MARK: - Computed Properties
    var filteredUsers: [GetAllUsersDM] {
        if searchText.isEmpty {
            return viewModel.availableUsers
        } else {
            return viewModel.availableUsers.filter { user in
                user.name.localizedCaseInsensitiveContains(searchText) ||
                user.id.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if viewModel.isLoading {
                    ProgressView("Loading users...")
                } else if viewModel.availableUsers.isEmpty {
                    emptyStateView
                } else {
                    mainContentView
                }
            }
            .navigationTitle("Add Members to \(chatName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add (\(viewModel.selectedUsers.count))") {
                        addMembers()
                    }
                    .disabled(viewModel.selectedUsers.isEmpty || viewModel.isAddingMembers)
                    .fontWeight(.semibold)
                }
            }
            .searchable(text: $searchText, prompt: "Search users...")
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .alert("Success", isPresented: .constant(viewModel.successMessage != nil)) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text(viewModel.successMessage ?? "")
            }
            .overlay {
                if viewModel.isAddingMembers {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                    ProgressView("Adding members...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                }
            }
        }
    }
    
    // MARK: - Subviews
    private var mainContentView: some View {
        List {
            Section {
                if filteredUsers.isEmpty {
                    Text("No users found")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    ForEach(filteredUsers) { user in
                        UserSelectionRow(
                            user: user,
                            isSelected: viewModel.isSelected(user),
                            onToggle: {
                                viewModel.toggleUserSelection(user)
                            }
                        )
                    }
                }
            } footer: {
                if !viewModel.selectedUsers.isEmpty {
                    Text("Selected \(viewModel.selectedUsers.count) member(s) to add")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Users Available")
                .font(.headline)
            
            Text("All users are already in this group or no other users are available")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Methods
    private func addMembers() {
        viewModel.addMembers { success in
            if success {
                // Optional: Post notification to refresh group details
                NotificationCenter.default.post(
                    name: NSNotification.Name("GroupMembersUpdated"),
                    object: nil,
                    userInfo: ["chatId": chatId]
                )
            }
        }
    }
}

// MARK: - User Selection Row (Reused from CreateRoomView)
// You can reuse the same UserSelectionRow component
