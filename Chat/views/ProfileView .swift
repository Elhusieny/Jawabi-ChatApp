//
//  ProfileView 2.swift
//  Chat
//
//  Created by Ahmed Elhussieny on 02/02/2026.
//


import SwiftUI
import PhotosUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfilePictureViewModel()
    @Binding var isPresented: Bool
    @State private var showingImageSource = false
    @State private var imageSource: UIImagePickerController.SourceType = .photoLibrary
    
    private let primaryColor = Color(hex: "#7373d2")
    private let gradientColors = [Color(hex: "#7373d2"), Color(hex: "#9d73d2")]
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [Color(.systemBackground).opacity(0.1), primaryColor.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                if viewModel.isLoading && viewModel.userProfile == nil {
                    LoadingView(primaryColor: primaryColor)
                } else {
                    ScrollView {
                        VStack(spacing: 30) {
                            // Profile Picture Section
                            ProfilePictureView(
                                userProfile: viewModel.userProfile,
                                selectedImage: viewModel.selectedImage,
                                isLoading: viewModel.isLoading,
                                onCameraTap: { showingImageSource = true },
                                initials: viewModel.getUserInitials()
                            )
                            
                            // Profile Info Section
                            ProfileInfoView(
                                userProfile: viewModel.userProfile,
                                isEditingProfile: viewModel.isEditingProfile,
                                tempName: $viewModel.tempName,
                                tempEmail: $viewModel.tempEmail,
                                tempPhoneNumber: $viewModel.tempPhoneNumber,
                                isLoading: viewModel.isLoading,
                                onSave: { viewModel.updateProfileInfo() },
                                onCancel: { viewModel.cancelEdit() },
                                formatPhoneNumber: viewModel.formatPhoneNumber
                            )
                            
                            // Upload Status
                            if viewModel.isUploading {
                                UploadProgressView(
                                    progress: viewModel.uploadProgress,
                                    primaryColor: primaryColor
                                )
                            }
                            
                            Spacer()
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    closeButton
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    trailingButton
                }
            }
            .sheet(isPresented: $viewModel.showImagePicker) {
                ImagePicker(sourceType: imageSource) { image in
                    viewModel.handleImageSelection(image)
                }
            }
            .actionSheet(isPresented: $showingImageSource) {
                imageSourceActionSheet
            }
            .alert("Success", isPresented: .constant(viewModel.successMessage != nil)) {
                successAlertButton
            } message: {
                successAlertMessage
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                errorAlertButton
            } message: {
                errorAlertMessage
            }
        }
    }
    
    // MARK: - Toolbar Buttons
    
    private var closeButton: some View {
        Button("Close") {
            isPresented = false
        }
        .foregroundStyle(
            LinearGradient(
                colors: gradientColors,
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }
    
    @ViewBuilder
    private var trailingButton: some View {
        if viewModel.isEditingProfile {
            Button("Save") {
                viewModel.updateProfileInfo()
            }
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.green, Color(hex: "#73d2a3")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .disabled(viewModel.isLoading)
        } else if viewModel.userProfile != nil {
            Button("Edit") {
                viewModel.isEditingProfile = true
            }
            .foregroundStyle(
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
    }
    
    // MARK: - Action Sheet
    
    private var imageSourceActionSheet: ActionSheet {
        ActionSheet(
            title: Text("Change Profile Picture"),
            message: Text("Choose a source"),
            buttons: [
                .default(Text("Take Photo")) {
                    imageSource = .camera
                    viewModel.showImagePicker = true
                },
                .default(Text("Choose from Library")) {
                    imageSource = .photoLibrary
                    viewModel.showImagePicker = true
                },
                .cancel()
            ]
        )
    }
    
    // MARK: - Alert Buttons
    
    private var successAlertButton: some View {
        Button("OK") {
            viewModel.successMessage = nil
        }
    }
    
    private var successAlertMessage: some View {
        Text(viewModel.successMessage ?? "")
    }
    
    private var errorAlertButton: some View {
        Button("OK") {
            viewModel.errorMessage = nil
        }
    }
    
    private var errorAlertMessage: some View {
        Text(viewModel.errorMessage ?? "")
    }
}
