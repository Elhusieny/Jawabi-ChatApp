
// MARK: - Full Screen Image
struct FullScreenImageView: View {
    let imageUrl: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                AsyncImage(url: URL(string: imageUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .failure:
                        VStack {
                            Image(systemName: "photo.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.white)
                            Text("Failed to load")
                                .foregroundColor(.white)
                        }
                    case .empty:
                        ProgressView()
                            .tint(.white)
                    @unknown default:
                        EmptyView()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

// MARK: - File Message View
struct FileMessageView: View {
    let fileUrl: String
    let fileName: String
    let isCurrentUser: Bool
    let bubbleForeground: Color
    let isBlocked: Bool
    
    private var primaryColor: Color { .jawabiPrimary }
    
    private var fileExtension: String {
        (fileName as NSString).pathExtension.uppercased()
    }
    
    private var fileIcon: String {
        switch fileExtension {
        case "PDF": return "doc.fill"
        case "DOC", "DOCX": return "doc.text.fill"
        case "TXT": return "doc.text"
        case "ZIP", "RAR": return "doc.zipper"
        default: return "doc"
        }
    }
    
    private var bubbleBackground: LinearGradient {
        if isCurrentUser {
            return LinearGradient(
                colors: [primaryColor, primaryColor.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [Color(.systemGray5), Color(.systemGray4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    var body: some View {
        if isBlocked {
            blockedContentView
        } else {
            normalContentView
        }
    }
    
    private var blockedContentView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 20))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("File Blocked")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.red)
                    
                    Text(fileName)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Text("This file was blocked for security reasons")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var normalContentView: some View {
        HStack(spacing: 12) {
            Button(action: openFile) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(isCurrentUser ? .white : primaryColor)
            }
            .buttonStyle(PlainButtonStyle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(fileName)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(2)
                
                Text(fileExtension)
                    .font(.system(size: 12))
                    .opacity(0.7)
            }
        }
        .padding(12)
        .background(bubbleBackground)
        .foregroundColor(bubbleForeground)
        .cornerRadius(12)
        .contextMenu {
            Button(action: {
                UIPasteboard.general.string = fileUrl
            }) {
                Label("Copy URL", systemImage: "doc.on.doc")
            }
            
            Button(action: openFile) {
                Label("Open File", systemImage: "arrow.down.circle")
            }
        }
    }
    
    private func openFile() {
        guard let url = URL(string: fileUrl) else { return }
        UIApplication.shared.open(url)
    }
}
