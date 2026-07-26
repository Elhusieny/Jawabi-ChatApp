import Foundation
import Combine
import SwiftUI

class RequestAccessVM: ObservableObject {
    
    /// Set of Combine cancellables for managing subscriptions
    var cancellables = Set<AnyCancellable>()
    
    /// Authentication service instance
    private let requestAccessService = RequestAccessService.shared
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showRequestAccessSuccess = false
    
    func requestAccess(
        userName: String,
        email: String,
        displayName: String,
        phoneNumber: String,
        password: String,
        companyName: String,
        profilePicture: Data?,
        serverUrl: String?
    ) {
        isLoading = true
        errorMessage = nil
        
        let request = RequestAccessRequest(
            userName: userName,
            email: email,
            displayName: displayName,
            phoneNumber: phoneNumber,
            password: password,
            companyName: companyName,
            profilePicture: profilePicture,
            serverUrl: serverUrl
        )
        
        requestAccessService.requestAccess(request)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                    print("Request access error: \(error)")
                }
            } receiveValue: { [weak self] message in
                print("Request access successful: \(message)")
                // Navigate to success screen or show alert
                self?.showRequestAccessSuccess = true
            }
            .store(in: &cancellables)
    }
}
