//
//  CreateRoomView.swift
//  Chat
//
//  Created by Ahmed Elhussieny on 23/11/2025.
//


import SwiftUI

struct CreateRoomView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var viewModel = CreateRoomViewModel()
    @State private var roomName = ""
    @State private var roomDescription = ""
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var gradientAnimation = false
    
    private let iconGradientColors: [Color] = [.blue, .purple, .pink]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Room Details")) {
                    TextField("Room Name", text: $roomName)
                        .textInputAutocapitalization(.words)
                    
                    TextField("Description (Optional)", text: $roomDescription)
                        .textInputAutocapitalization(.sentences)
                }
                
                Section(header: Text("Room Image")) {
                    Button(action: {
                        showingImagePicker = true
                    }) {
                        HStack {
                            Image(systemName: "photo.circle.fill")
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: iconGradientColors,
                                        startPoint: gradientAnimation ? .top : .leading,
                                        endPoint: gradientAnimation ? .bottom : .trailing
                                    )
                                )
                                .font(.title2)
                            
                            Text(selectedImage == nil ? "Add Room Image" : "Change Room Image")
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if selectedImage != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    
                    if let image = selectedImage {
                        HStack {
                            Spacer()
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                Section(header: Text("Select Members")) {
                    if viewModel.availableUsers.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                ProgressView()
                                Text("Loading users...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    } else {
                        ForEach(viewModel.availableUsers) { user in
                            UserSelectionRow(
                                user: user,
                                isSelected: viewModel.selectedUsers.contains(where: { $0.id == user.id }),
                                onToggle: {
                                    viewModel.toggleUserSelection(user)
                                }
                            )
                        }
                    }
                }
                
                if !viewModel.selectedUsers.isEmpty {
                    Section(header: Text("Selected Members (\(viewModel.selectedUsers.count))")) {
                        ForEach(viewModel.selectedUsers) { user in
                            HStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.2))
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Text(user.name.prefix(1).uppercased())
                                            .font(.headline)
                                            .foregroundColor(.blue)
                                    )
                                
                                VStack(alignment: .leading) {
                                    Text(user.name)
                                        .font(.headline)
                                    Text(user.id)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button("Remove") {
                                    viewModel.toggleUserSelection(user)
                                }
                                .foregroundColor(.red)
                                .font(.caption)
                            }
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        createRoom()
                    }) {
                        HStack {
                            Spacer()
                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "person.2.fill")
                                Text("Create Room")
                            }
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(10)
                    }
                    .disabled(roomName.isEmpty || viewModel.selectedUsers.isEmpty || viewModel.isLoading)
                }
            }
            .navigationTitle("Create Room")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $selectedImage)
            }
            .onAppear {
                viewModel.loadAvailableUsers()
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    gradientAnimation.toggle()
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .alert("Success", isPresented: .constant(viewModel.successMessage != nil)) {
                Button("OK") {
                    presentationMode.wrappedValue.dismiss()
                }
            } message: {
                Text(viewModel.successMessage ?? "")
            }
        }
    }
    
    private func createRoom() {
        let memberIds = viewModel.selectedUsers.map { $0.id }
        viewModel.createRoom(
            name: roomName,
            description: roomDescription.isEmpty ? nil : roomDescription,
            memberIds: memberIds,
            image: selectedImage
        )
    }
}

// MARK: - User Selection Row
struct UserSelectionRow: View {
    let user: APIUser
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(user.name.prefix(1).uppercased())
                            .font(.headline)
                            .foregroundColor(.blue)
                    )
                
                VStack(alignment: .leading) {
                    Text(user.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(user.id)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .green : .gray)
                    .font(.title2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

//// MARK: - Image Picker
//struct ImagePicker: UIViewControllerRepresentable {
//    @Binding var image: UIImage?
//    @Environment(\.presentationMode) var presentationMode
//    
//    func makeUIViewController(context: Context) -> UIImagePickerController {
//        let picker = UIImagePickerController()
//        picker.delegate = context.coordinator
//        picker.allowsEditing = true
//        return picker
//    }
//    
//    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
//    
//    func makeCoordinator() -> Coordinator {
//        Coordinator(self)
//    }
//    
//    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
//        let parent: ImagePicker
//        
//        init(_ parent: ImagePicker) {
//            self.parent = parent
//        }
//        
//        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
//            if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
//                parent.image = image
//            }
//            parent.presentationMode.wrappedValue.dismiss()
//        }
//        
//        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
//            parent.presentationMode.wrappedValue.dismiss()
//        }
//    }
//}
