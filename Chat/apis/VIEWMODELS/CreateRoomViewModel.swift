import Combine
import SwiftUI


class CreateRoomViewModel: ObservableObject {
    @Published var availableUsers: [APIUser] = []
    @Published var selectedUsers: [APIUser] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    private let groupRoomService: GroupRoomServiceProtocol
    
    init(groupRoomService: GroupRoomServiceProtocol = GroupRoomService.shared) {
        self.groupRoomService = groupRoomService
    }
    
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
                // Filter out current user
                let currentUserId = self?.getCurrentUserId() ?? ""
                self?.availableUsers = users.filter { $0.id != currentUserId }
                print("✅ Loaded \(users.count) available users")
            }
            .store(in: &cancellables)
    }
    
    func toggleUserSelection(_ user: APIUser) {
        if let index = selectedUsers.firstIndex(where: { $0.id == user.id }) {
            selectedUsers.remove(at: index)
        } else {
            selectedUsers.append(user)
        }
        print("👤 Selected users: \(selectedUsers.count)")
    }
    
    func createRoom(name: String, description: String?, memberIds: [String], image: UIImage?) {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Room name cannot be empty"
            return
        }
        
        guard !memberIds.isEmpty else {
            errorMessage = "Please select at least one member"
            return
        }
        
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        // Convert UIImage to base64 string if provided
        var chatPicture: String?
        if let image = image {
            chatPicture = convertImageToBase64(image)
            print("📸 Image converted to base64: \(chatPicture?.prefix(50) ?? "nil")...")
        }
        
        let request = CreateRoomRequest(
            name: name,
            chatPicture: chatPicture,
            memberIds: memberIds
        )
        
        print("🎯 Creating room: \(name) with \(memberIds.count) members")
        
        groupRoomService.createRoom(request)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                switch completion {
                case .failure(let error):
                    let errorMessage = "Failed to create room: \(error.localizedDescription)"
                    self?.errorMessage = errorMessage
                    print("❌ Room creation failed: \(errorMessage)")
                case .finished:
                    print("✅ Room creation request completed")
                }
            } receiveValue: { [weak self] response in
                print("📨 Response received: \(response)")
                
                if response.isSuccess {
                    let successMsg = response.message ?? "Room created successfully!"
                    self?.successMessage = successMsg
                    self?.selectedUsers.removeAll()
                    print("✅ Room created: \(successMsg)")
                    
                    // You might want to refresh the rooms list here
                    // NotificationCenter.default.post(name: .roomsDidUpdate, object: nil)
                } else {
                    let errorMsg = response.message ?? "Failed to create room"
                    self?.errorMessage = errorMsg
                    print("❌ Room creation failed: \(errorMsg)")
                }
            }
            .store(in: &cancellables)
    }
    
    private func convertImageToBase64(_ image: UIImage) -> String? {
        guard let imageData = image.jpegData(compressionQuality: 0.5) else {
            print("❌ Failed to convert image to JPEG data")
            return nil
        }
        let base64String = imageData.base64EncodedString()
        print("📸 Image converted to base64, length: \(base64String.count)")
        return base64String
    }
    
    private func getCurrentUserId() -> String {
        return UserDefaults.standard.string(forKey: "currentUserId") ?? ""
    }
}
