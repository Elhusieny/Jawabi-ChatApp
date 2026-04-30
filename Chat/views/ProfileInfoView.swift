import SwiftUI

struct ProfileInfoView: View {
    let userProfile: UserProfile?
    let isEditingProfile: Bool
    let tempName: Binding<String>
    let tempEmail: Binding<String>
    let tempPhoneNumber: Binding<String>
    let isLoading: Bool
    let onSave: () -> Void
    let onCancel: () -> Void
    let formatPhoneNumber: (String) -> String
    
    private let gradientColors = [Color(hex: "#7373d2"), Color(hex: "#9d73d2")]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Profile Information")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            VStack(spacing: 16) {
                // Name Field
                profileField(
                    title: "Name",
                    value: userProfile?.displayName ?? "Unknown",
                    isEditing: isEditingProfile,
                    binding: tempName,
                    placeholder: "Enter your name"
                )
                .autocapitalization(.words)
                
                // Email Field
                profileField(
                    title: "Email",
                    value: userProfile?.email ?? "No email",
                    isEditing: isEditingProfile,
                    binding: tempEmail,
                    placeholder: "Enter your email"
                )
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                
                // Phone Field
                profileField(
                    title: "Phone Number",
                    value: formatPhoneNumber(userProfile?.phoneNumber ?? ""),
                    isEditing: isEditingProfile,
                    binding: tempPhoneNumber,
                    placeholder: "Enter your phone number"
                )
                .keyboardType(.phonePad)
                .autocapitalization(.none)
            }
            
            if isEditingProfile {
                editButtons
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
    
    @ViewBuilder
    private func profileField(
        title: String,
        value: String,
        isEditing: Bool,
        binding: Binding<String>,
        placeholder: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            if isEditing {
                TextField(placeholder, text: binding)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            } else {
                Text(value)
                    .font(.body)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
        }
    }
    
    private var editButtons: some View {
        HStack(spacing: 12) {
            Button("Cancel", action: onCancel)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray5))
                .foregroundColor(.primary)
                .cornerRadius(10)
            
            Button("Save Changes") {
                onSave()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(10)
            .disabled(isLoading)
        }
    }
}
