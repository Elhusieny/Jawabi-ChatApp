import Combine
import Foundation

class GroupRoomViewModel: ObservableObject {
    @Published var groupRooms: [GroupRoom] = []
    @Published var currentRoom: GroupRoom?
    @Published var availableUsers: [APIUser] = []
    @Published var selectedUsers: [APIUser] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    private let groupChatService: GroupChatServiceProtocol
    
    // Local storage key
    private var roomsKey: String {
        if let currentUser = getCurrentUsername() {
            return "group_rooms_\(currentUser)"
        }
        return "group_rooms_anonymous"
    }
    
    init(groupChatService: GroupChatServiceProtocol = GroupChatService.shared) {
        self.groupChatService = groupChatService
        loadSavedRooms()
    }
    
    // MARK: - Local Storage
    private func saveRooms() {
        if let encoded = try? JSONEncoder().encode(groupRooms) {
            UserDefaults.standard.set(encoded, forKey: roomsKey)
            print("💾 Saved \(groupRooms.count) group rooms")
        }
    }
    
    private func loadSavedRooms() {
        if let savedRoomsData = UserDefaults.standard.data(forKey: roomsKey),
           let savedRooms = try? JSONDecoder().decode([GroupRoom].self, from: savedRoomsData) {
            self.groupRooms = savedRooms
            print("📂 Loaded \(savedRooms.count) group rooms from storage")
        } else {
            self.groupRooms = []
        }
    }
    
  
    // MARK: - Join Room
    func joinRoom(roomId: Int) {
        isLoading = true
        errorMessage = nil
        
        groupChatService.joinRoom(roomId: roomId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                switch completion {
                case .failure(let error):
                    self?.errorMessage = "Failed to join room: \(error.localizedDescription)"
                    print("❌ Error joining room: \(error)")
                case .finished:
                    print("✅ Join room request completed")
                }
            } receiveValue: { [weak self] response in
                if response.success == true || response.result == "Joined room successfully" {
                    self?.successMessage = "Successfully joined the room!"
                    // Load room details after joining
                    self?.loadRoomDetails(roomId: roomId)
                    print("✅ Joined room successfully")
                } else {
                    self?.errorMessage = response.error ?? response.message ?? "Failed to join room"
                    print("❌ Join room failed: \(response.error ?? "Unknown error")")
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Load Room Details
    func loadRoomDetails(roomId: Int) {
        isLoading = true
        
        groupChatService.getRoomDetails(roomId: roomId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = "Failed to load room details: \(error.localizedDescription)"
                    print("❌ Error loading room details: \(error)")
                }
            } receiveValue: { [weak self] room in
                self?.currentRoom = room
                
                // Update in rooms list if exists, otherwise add it
                if let index = self?.groupRooms.firstIndex(where: { $0.id == room.id }) {
                    self?.groupRooms[index] = room
                } else {
                    self?.groupRooms.insert(room, at: 0)
                }
                
                self?.saveRooms()
                print("✅ Loaded room details: \(room.name) with \(room.members.count) members")
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Load Group Rooms
    func loadGroupRooms() {
        isLoading = true
        errorMessage = nil
        
        groupChatService.getGroupRooms()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = "Failed to load group rooms: \(error.localizedDescription)"
                    print("❌ Error loading group rooms: \(error)")
                }
            } receiveValue: { [weak self] rooms in
                self?.groupRooms = rooms
                self?.saveRooms()
                print("✅ Loaded \(rooms.count) group rooms")
            }
            .store(in: &cancellables)
    }
    
    // MARK: - User Management
    func loadAvailableUsers() {
        isLoading = true
        
        GetAllUsersService.shared.getAllUsers()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = "Failed to load users: \(error.localizedDescription)"
                }
            } receiveValue: { [weak self] users in
                // Filter out already selected users and current user
                let currentUserId = self?.getCurrentUserId() ?? ""
                let selectedUserIds = self?.selectedUsers.map { $0.id } ?? []
                
                self?.availableUsers = users.filter {
                    $0.id != currentUserId && !selectedUserIds.contains($0.id)
                }
                print("✅ Loaded \(users.count) available users")
            }
            .store(in: &cancellables)
    }
    
    func selectUser(_ user: APIUser) {
        if !selectedUsers.contains(where: { $0.id == user.id }) {
            selectedUsers.append(user)
            availableUsers.removeAll { $0.id == user.id }
            print("✅ Selected user: \(user.name)")
        }
    }
    
    func deselectUser(_ user: APIUser) {
        selectedUsers.removeAll { $0.id == user.id }
        if user.id != getCurrentUserId() && !availableUsers.contains(where: { $0.id == user.id }) {
            availableUsers.append(user)
        }
        print("❌ Deselected user: \(user.name)")
    }
    
    // MARK: - Room Management
    func clearCurrentRoom() {
        currentRoom = nil
    }
    
    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
    
    func deleteRoomFromList(roomId: Int) {
        groupRooms.removeAll { $0.id == roomId }
        saveRooms()
        print("🗑️ Removed room with ID: \(roomId) from local storage")
    }
    
    func clearUserRooms() {
        groupRooms.removeAll()
        UserDefaults.standard.removeObject(forKey: roomsKey)
        print("🧹 Cleared all user rooms from storage")
    }
    
    // MARK: - Helper Methods
    private func getCurrentUserId() -> String {
        return UserDefaults.standard.string(forKey: "currentUserId") ?? ""
    }
    
    private func getCurrentUsername() -> String? {
        return UserDefaults.standard.string(forKey: "currentUsername")
    }
}
