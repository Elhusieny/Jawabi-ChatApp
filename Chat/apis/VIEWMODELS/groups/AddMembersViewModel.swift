//
//  AddMembersViewModel.swift
//  Chat
//
//  Created by Ahmed Elhussieny on 12/05/2026.
//

import Foundation
import SwiftUI
import Combine

class AddMembersViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var availableUsers: [GetAllUsersDM] = []
    @Published var selectedUsers: [GetAllUsersDM] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var isAddingMembers = false
    
    // MARK: - Private Properties
    private let addMembersService: AddMembersServiceProtocol
    private let getAllUsersService = GetAllUsersService.shared
    private var cancellables = Set<AnyCancellable>()
    private let chatId: Int
    private let existingMemberIds: Set<String>
    
    // MARK: - Initialization
    init(chatId: Int, existingMembers: [String] = []) {
        self.chatId = chatId
        self.existingMemberIds = Set(existingMembers)
        self.addMembersService = AddMembersService.shared
        loadAvailableUsers()
    }
    
    // MARK: - Public Methods
    
    /// Load all users except current user and existing members
    func loadAvailableUsers() {
        isLoading = true
        errorMessage = nil
        
        let currentUserId = getCurrentUserId()
        
        getAllUsersService.getAllUsers()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = "Failed to load users: \(error.localizedDescription)"
                    print("❌ Failed to load users: \(error)")
                }
            } receiveValue: { [weak self] allUsers in
                guard let self = self else { return }
                // Filter out current user and existing members
                let available = allUsers.filter { user in
                    user.id != currentUserId && !self.existingMemberIds.contains(user.id)
                }
                self.availableUsers = available
                print("✅ Loaded \(available.count) available users for adding to group")
            }
            .store(in: &cancellables)
    }
    
    /// Toggle user selection
    func toggleUserSelection(_ user: GetAllUsersDM) {
        if selectedUsers.contains(where: { $0.id == user.id }) {
            selectedUsers.removeAll { $0.id == user.id }
        } else {
            selectedUsers.append(user)
        }
    }
    
    /// Add selected members to the group
    func addMembers(completion: @escaping (Bool) -> Void) {
        guard !selectedUsers.isEmpty else {
            errorMessage = "Please select at least one member to add"
            completion(false)
            return
        }
        
        isAddingMembers = true
        errorMessage = nil
        successMessage = nil
        
        let memberIds = selectedUsers.map { $0.id }
        
        print("➕ Adding \(memberIds.count) members to chat \(chatId)")
        
        addMembersService.addMembers(chatId: chatId, memberIds: memberIds)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completionStatus in
                self?.isAddingMembers = false
                
                switch completionStatus {
                case .failure(let error):
                    self?.errorMessage = "Failed to add members: \(error.localizedDescription)"
                    print("❌ Error adding members: \(error)")
                    completion(false)
                    
                case .finished:
                    break
                }
            } receiveValue: { [weak self] response in
                guard let self = self else { return }
                
                if response.isSuccess {
                    let memberNames = self.selectedUsers.map { $0.name }.joined(separator: ", ")
                    self.successMessage = "Successfully added \(self.selectedUsers.count) member(s): \(memberNames)"
                    print("✅ Members added successfully")
                    
                    // Post notification to refresh chat list
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ChatMembersUpdated"),
                        object: nil,
                        userInfo: ["chatId": self.chatId]  // FIXED: Added 'self.'
                    )
                    
                    completion(true)
                } else {
                    self.errorMessage = response.message ?? "Failed to add members"
                    completion(false)
                }
            }
            .store(in: &cancellables)
    }
    
    /// Check if user is already selected
    func isSelected(_ user: GetAllUsersDM) -> Bool {
        selectedUsers.contains { $0.id == user.id }
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentUserId() -> String {
        if let userId = UserDefaults.standard.string(forKey: "currentUserId") {
            return userId
        }
        if let userId = UserDefaults.standard.string(forKey: "userId") {
            return userId
        }
        return ""
    }
}
