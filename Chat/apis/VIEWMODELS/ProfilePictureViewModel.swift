import Foundation
import Combine
import SwiftUI

class ProfilePictureViewModel: ObservableObject {
    @Published var userProfile: UserProfile?
    @Published var isLoading = false
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0.0
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var selectedImage: UIImage?
    @Published var showImagePicker = false
    @Published var showActionSheet = false
    @Published var isEditingProfile = false
    @Published var tempName: String = ""
    @Published var tempEmail: String = ""
    @Published var tempPhoneNumber: String = ""
    
    private let profilePictureService: ProfilePictureServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(service: ProfilePictureServiceProtocol = ProfilePictureService.shared) {
        self.profilePictureService = service
        loadUserProfile()
    }
    
    // MARK: - Load User Profile
    func loadUserProfile() {
        isLoading = true
        errorMessage = nil
        
        profilePictureService.getUserProfile()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = "Failed to load profile: \(error.localizedDescription)"
                    print("❌ Profile load error: \(error)")
                }
            } receiveValue: { [weak self] userProfile in
                self?.userProfile = userProfile
                self?.tempName = userProfile.name
                self?.tempEmail = userProfile.email
                self?.tempPhoneNumber = userProfile.phoneNumber
                print("✅ Profile loaded: \(userProfile.name)")
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Upload Profile Picture
    func uploadProfilePicture() {
        guard let image = selectedImage else {
            errorMessage = "No image selected"
            return
        }
        
        isUploading = true
        uploadProgress = 0.0
        errorMessage = nil
        successMessage = nil
        
        profilePictureService.uploadProfilePicture(image)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isUploading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = "Upload failed: \(error.localizedDescription)"
                    print("❌ Upload error: \(error)")
                }
            } receiveValue: { [weak self] response in
                if response.isSuccess {
                    self?.successMessage = response.message ?? "Profile picture updated successfully!"
                    
                    // Reload profile to get updated picture
                    self?.loadUserProfile()
                    
                    // Clear selected image
                    self?.selectedImage = nil
                    
                    print("✅ Profile picture uploaded successfully")
                } else {
                    self?.errorMessage = response.message ?? "Upload failed"
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Update User Profile Info
    func updateProfileInfo() {
        guard tempName != userProfile?.name || 
              tempEmail != userProfile?.email || 
              tempPhoneNumber != userProfile?.phoneNumber else {
            isEditingProfile = false
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        profilePictureService.updateUserProfile(
            name: tempName,
            email: tempEmail,
            phoneNumber: tempPhoneNumber
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] completion in
            self?.isLoading = false
            if case .failure(let error) = completion {
                self?.errorMessage = "Update failed: \(error.localizedDescription)"
            }
        } receiveValue: { [weak self] updatedProfile in
            self?.userProfile = updatedProfile
            self?.successMessage = "Profile updated successfully!"
            self?.isEditingProfile = false
            print("✅ Profile info updated")
        }
        .store(in: &cancellables)
    }
    
    // MARK: - Image Picker Handlers
    func selectImageFromSource(_ source: UIImagePickerController.SourceType) {
        // This will be handled by the view
        showImagePicker = true
    }
    
    func handleImageSelection(_ image: UIImage) {
        selectedImage = image
        // Auto-upload after selection
        uploadProfilePicture()
    }
    
    // MARK: - Cancel Edit
    func cancelEdit() {
        tempName = userProfile?.name ?? ""
        tempEmail = userProfile?.email ?? ""
        tempPhoneNumber = userProfile?.phoneNumber ?? ""
        isEditingProfile = false
        selectedImage = nil
    }
    
    // MARK: - Format Phone Number
    func formatPhoneNumber(_ phone: String) -> String {
        let digits = phone.filter { $0.isNumber }
        
        switch digits.count {
        case 10:
            let areaCode = String(digits.prefix(3))
            let prefix = String(digits.dropFirst(3).prefix(3))
            let lineNumber = String(digits.dropFirst(6))
            return "(\(areaCode)) \(prefix)-\(lineNumber)"
        case 11 where digits.hasPrefix("1"):
            let rest = String(digits.dropFirst())
            let areaCode = String(rest.prefix(3))
            let prefix = String(rest.dropFirst(3).prefix(3))
            let lineNumber = String(rest.dropFirst(6))
            return "+1 (\(areaCode)) \(prefix)-\(lineNumber)"
        default:
            return phone
        }
    }
    
    // MARK: - Get User Initials
    func getUserInitials() -> String {
        return userProfile?.name.getInitials() ?? "?"
    }
    
    // MARK: - Clear Messages
    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
}