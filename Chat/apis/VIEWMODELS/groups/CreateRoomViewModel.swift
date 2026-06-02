import Combine
import SwiftUI


class CreateRoomViewModel: ObservableObject {
    @Published var availableUsers: [GetAllUsersDM] = []
    @Published var selectedUsers: [GetAllUsersDM] = []
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
    
    func toggleUserSelection(_ user: GetAllUsersDM) {
        if let index = selectedUsers.firstIndex(where: { $0.id == user.id }) {
            selectedUsers.remove(at: index)
        } else {
            selectedUsers.append(user)
        }
        print("👤 Selected users: \(selectedUsers.count)")
    }
    // CreateRoomViewModel.swift - Updated createRoom method

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
        
        // Convert UIImage to base64 string if provided with better compression
        var chatPicture: String?
        if let image = image {
            // Resize image to reasonable size before converting
            let resizedImage = resizeImage(image, targetSize: CGSize(width: 500, height: 500))
            chatPicture = convertImageToBase64(resizedImage)
            print("📸 Image converted to base64, length: \(chatPicture?.count ?? 0)")
        }
        
        let request = CreateRoomRequest(
            name: name,
            chatPicture: chatPicture,
            memberIds: memberIds
        )
        
        print("🎯 Creating room: \(name) with \(memberIds.count) members")
        print("📸 Has image: \(chatPicture != nil)")
        
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
                    
                    // Post notification to refresh chat list
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        NotificationCenter.default.post(name: NSNotification.Name("ChatListShouldRefresh"), object: nil)
                    }
                } else {
                    let errorMsg = response.message ?? "Failed to create room"
                    self?.errorMessage = errorMsg
                    print("❌ Room creation failed: \(errorMsg)")
                }
            }
            .store(in: &cancellables)
    }

    // Add this helper method to resize image
    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size
        
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        
        let newSize: CGSize
        if widthRatio > heightRatio {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio, height: size.height * widthRatio)
        }
        
        let rect = CGRect(origin: .zero, size: newSize)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage ?? image
    }

    private func convertImageToBase64(_ image: UIImage) -> String? {
        // Use JPEG with 0.7 quality for better balance
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            print("❌ Failed to convert image to JPEG data")
            return nil
        }
        let base64String = imageData.base64EncodedString()
        print("📸 Image converted to base64, size: \(imageData.count / 1024) KB")
        return base64String
    }
    
    private func getCurrentUserId() -> String {
        return UserDefaults.standard.string(forKey: "currentUserId") ?? ""
    }
}
