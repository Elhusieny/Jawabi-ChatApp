// JawabiAvatar.swift
import SwiftUI

struct JawabiAvatar: View {
    let name: String
    let imageUrl: String?
    let size: CGFloat
    let isGroup: Bool
    
    init(name: String, imageUrl: String? = nil, size: CGFloat = 52, isGroup: Bool = false) {
        self.name = name
        self.imageUrl = imageUrl
        self.size = size
        self.isGroup = isGroup
    }
    
    var body: some View {
        if let url = imageUrl, !url.isEmpty, !url.contains("default.png") {
            AsyncImage(url: URL(string: url)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.jawabiPrimary, lineWidth: 2)
                        )
                default:
                    fallbackAvatar
                }
            }
        } else {
            fallbackAvatar
        }
    }
    
    private var fallbackAvatar: some View {
        Circle()
            .fill(Color.jawabiPrimary.opacity(0.3))
            .frame(width: size, height: size)
            .overlay(
                Group {
                    if isGroup {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: size * 0.4))
                            .foregroundColor(.white)
                    } else {
                        Text(name.getInitials())
                            .font(.system(size: size * 0.4, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            )
            .overlay(
                Circle()
                    .stroke(Color.jawabiPrimary, lineWidth: 2)
            )
    }
}