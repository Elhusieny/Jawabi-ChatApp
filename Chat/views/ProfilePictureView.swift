import SwiftUI

struct ProfilePictureView: View {
    let userProfile: UserProfile?
    let selectedImage: UIImage?
    let isLoading: Bool
    let onCameraTap: () -> Void
    let initials: String
    
    private let gradientColors = [Color(hex: "#7373d2"), Color(hex: "#9d73d2")]
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack(alignment: .bottomTrailing) {
                // Profile Image
                if let selectedImage = selectedImage {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 150, height: 150)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: gradientColors,
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 4
                                )
                        )
                        .shadow(color: Color(hex: "#7373d2").opacity(0.3), radius: 10)
                } else if let userProfile = userProfile {
                    if userProfile.isDefaultImage {
                        // Default image with initials
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#7373d2").opacity(0.3), Color(hex: "#9d73d2").opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 150, height: 150)
                            .overlay(
                                Text(initials)
                                    .font(.system(size: 50, weight: .bold))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: gradientColors,
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: gradientColors,
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 4
                                    )
                            )
                    } else {
                        // Actual profile image
                        AsyncImage(url: URL(string: userProfile.fullPictureUrl)) { phase in
                            switch phase {
                            case .empty:
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 150, height: 150)
                                    .overlay(
                                        ProgressView()
                                            .scaleEffect(1.2)
                                            .tint(Color(hex: "#7373d2"))
                                    )
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 150, height: 150)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                LinearGradient(
                                                    colors: gradientColors,
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 4
                                            )
                                    )
                            case .failure:
                                // Fallback
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: "#7373d2").opacity(0.3), Color(hex: "#9d73d2").opacity(0.3)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 150, height: 150)
                                    .overlay(
                                        Text(initials)
                                            .font(.system(size: 50, weight: .bold))
                                            .foregroundStyle(
                                                LinearGradient(
                                                    colors: gradientColors,
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                    )
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }
                }
                
                // Edit Button
                Button(action: onCameraTap) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#73d2a3"), Color.green],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.title3)
                                .foregroundColor(.white)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 5)
                }
                .offset(x: 10, y: 10)
            }
            
            Text("Tap camera to change photo")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
