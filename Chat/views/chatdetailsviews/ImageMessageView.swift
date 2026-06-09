
//import SwiftUI
//struct ImageMessageView: View {
//    let imageUrl: String
//        let isCurrentUser: Bool
//        let isBlocked: Bool
//        
//        @State private var showFullScreen = false
//        @State private var imageLoadError: Error?
//        @State private var isLoading = false
//        
//        private var cleanedImageUrl: String {
//            // Clean and encode the URL
//            let cleaned = imageUrl.trimmingCharacters(in: .whitespacesAndNewlines)
//            
//            // If it's already a full URL, return it encoded
//            if cleaned.hasPrefix("http://") || cleaned.hasPrefix("https://") {
//                if let encoded = cleaned.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
//                    print("🖼️ Encoded full URL: \(encoded)")
//                    return encoded
//                }
//            }
//            
//            // Handle file paths from server
//            let baseUrl = "http://158.220.90.131:8444"
//            
//            // If it starts with /uploads (from FileStatusUpdated event)
//            if cleaned.hasPrefix("/uploads") {
//                let fullUrl = "\(baseUrl)\(cleaned)"
//                if let encoded = fullUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
//                    print("🖼️ Built URL from /uploads path: \(encoded)")
//                    return encoded
//                }
//                return fullUrl
//            }
//            
//            // If it's just a filename (like image.jpg)
//            let fullUrl = "\(baseUrl)/uploads/\(cleaned)"
//            if let encoded = fullUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
//                print("🖼️ Built URL from filename: \(encoded)")
//                return encoded
//            }
//            
//            print("⚠️ Could not build proper URL for: \(cleaned)")
//            return cleaned
//        }
//    
//    var body: some View {
//        if isBlocked {
//            blockedContentView
//        } else {
//            normalContentView
//        }
//    }
//    private var blockedContentView: some View {
//        VStack(alignment: .leading, spacing: 8) {
//            HStack {
//                Image(systemName: "exclamationmark.triangle.fill")
//                    .foregroundColor(.red)
//                
//                Text("Image Blocked")
//                    .font(.system(size: 14, weight: .semibold))
//                    .foregroundColor(.red)
//            }
//            
//            Text("This image was blocked for security reasons")
//                .font(.system(size: 12))
//                .foregroundColor(.secondary)
//                .multilineTextAlignment(.leading)
//        }
//        .padding(12)
//        .background(Color.red.opacity(0.1))
//        .cornerRadius(12)
//        .overlay(
//            RoundedRectangle(cornerRadius: 12)
//                .stroke(Color.red.opacity(0.3), lineWidth: 1)
//        )
//    }
//    private var normalContentView: some View {
//           VStack(alignment: .leading, spacing: 8) {
//               AsyncImage(url: URL(string: cleanedImageUrl)) { phase in
//                   switch phase {
//                   case .empty:
//                       ProgressView()
//                           .frame(width: 200, height: 200)
//                           .background(Color.gray.opacity(0.1))
//                           .cornerRadius(12)
//                           .onAppear {
//                               print("🖼️ Loading image from: \(cleanedImageUrl)")
//                               print("   Original URL: \(imageUrl)")
//                               isLoading = true
//                           }
//                       
//                   case .success(let image):
//                       image
//                           .resizable()
//                           .aspectRatio(contentMode: .fill)
//                           .frame(maxWidth: 250, maxHeight: 300)
//                           .clipped()
//                           .cornerRadius(12)
//                           .onTapGesture {
//                               showFullScreen = true
//                           }
//                           .onAppear {
//                               print("✅ Image loaded successfully: \(cleanedImageUrl)")
//                               isLoading = false
//                               imageLoadError = nil
//                           }
//                       
//                   case .failure(let error):
//                       errorContentView(error: error)
//                       
//                   @unknown default:
//                       EmptyView()
//                   }
//               }
//           }
//           .contextMenu {
//               Button(action: {
//                   UIPasteboard.general.string = cleanedImageUrl
//               }) {
//                   Label("Copy URL", systemImage: "doc.on.doc")
//               }
//               
//               Button(action: {
//                   downloadImage()
//               }) {
//                   Label("Save Image", systemImage: "square.and.arrow.down")
//               }
//           }
//           .sheet(isPresented: $showFullScreen) {
//               FullScreenImageView(imageUrl: cleanedImageUrl)
//           }
//       }
//       
//    
//    private func errorContentView(error: Error) -> some View {
//        VStack(spacing: 8) {
//            Image(systemName: "exclamationmark.triangle")
//                .font(.system(size: 30))
//                .foregroundColor(.orange)
//            
//            Text("Failed to load image")
//                .font(.caption)
//                .foregroundColor(.gray)
//            
//            Button("Retry") {
//                // The AsyncImage will retry automatically when state changes
//                // We can force a refresh by changing the URL slightly
//            }
//            .font(.caption)
//            .padding(.horizontal, 12)
//            .padding(.vertical, 4)
//            .background(Color.blue.opacity(0.1))
//            .cornerRadius(8)
//        }
//        .frame(width: 200, height: 200)
//        .background(Color.gray.opacity(0.1))
//        .cornerRadius(12)
//        .onAppear {
//            print("❌ Image failed to load: \(cleanedImageUrl)")
//            print("   Error: \(error)")
//            isLoading = false
//            imageLoadError = error
//        }
//    }
//    
//    private func downloadImage() {
//        guard let url = URL(string: cleanedImageUrl) else {
//            print("❌ Invalid URL for download")
//            return
//        }
//        
//        print("⬇️ Downloading image from: \(url.absoluteString)")
//        
//        URLSession.shared.dataTask(with: url) { data, response, error in
//            if let error = error {
//                print("❌ Download error: \(error)")
//                return
//            }
//            
//            guard let data = data, let image = UIImage(data: data) else {
//                print("❌ Invalid image data")
//                return
//            }
//            
//            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
//            print("✅ Image saved to photos album")
//        }.resume()
//    }
//}
//
//
///// MARK: - Full Screen Image
//struct FullScreenImageView: View {
//    let imageUrl: String
//    @Environment(\.dismiss) var dismiss
//    
//    var body: some View {
//        NavigationView {
//            ZStack {
//                Color.black.ignoresSafeArea()
//                
//                AsyncImage(url: URL(string: imageUrl)) { phase in
//                    switch phase {
//                    case .success(let image):
//                        image
//                            .resizable()
//                            .aspectRatio(contentMode: .fit)
//                    case .failure:
//                        VStack {
//                            Image(systemName: "photo.fill")
//                                .font(.system(size: 60))
//                                .foregroundColor(.white)
//                            Text("Failed to load")
//                                .foregroundColor(.white)
//                        }
//                    case .empty:
//                        ProgressView()
//                            .tint(.white)
//                    @unknown default:
//                        EmptyView()
//                    }
//                }
//            }
//            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .navigationBarTrailing) {
//                    Button("Done") {
//                        dismiss()
//                    }
//                    .foregroundColor(.white)
//                }
//            }
//        }
//    }
//}
//
//
//struct FileMessageView: View {
//    let fileUrl: String
//    let fileName: String
//    let isCurrentUser: Bool
//    let bubbleForeground: Color
//    let isBlocked: Bool
//    
//    private var fileExtension: String {
//        (fileName as NSString).pathExtension.uppercased()
//    }
//    
//    private var fileIcon: String {
//        switch fileExtension {
//        case "PDF": return "doc.fill"
//        case "DOC", "DOCX": return "doc.text.fill"
//        case "TXT": return "doc.text"
//        case "ZIP", "RAR": return "doc.zipper"
//        default: return "doc"
//        }
//    }
//    
//    private var bubbleBackground: LinearGradient {
//        if isCurrentUser {
//            return LinearGradient(
//                colors: [.blue, .purple],
//                startPoint: .topLeading,
//                endPoint: .bottomTrailing
//            )
//        } else {
//            return LinearGradient(
//                colors: [Color(.systemGray5), Color(.systemGray4)],
//                startPoint: .topLeading,
//                endPoint: .bottomTrailing
//            )
//        }
//    }
//    
//    var body: some View {
//        if isBlocked {
//            blockedContentView
//        } else {
//            normalContentView
//        }
//    }
//    
//    private var blockedContentView: some View {
//        VStack(alignment: .leading, spacing: 8) {
//            HStack {
//                Image(systemName: "exclamationmark.triangle.fill")
//                    .foregroundColor(.red)
//                    .font(.system(size: 20))
//                
//                VStack(alignment: .leading, spacing: 2) {
//                    Text("File Blocked")
//                        .font(.system(size: 14, weight: .semibold))
//                        .foregroundColor(.red)
//                    
//                    Text(fileName)
//                        .font(.system(size: 12))
//                        .foregroundColor(.secondary)
//                        .lineLimit(1)
//                }
//            }
//            
//            Text("This file was blocked for security reasons")
//                .font(.system(size: 11))
//                .foregroundColor(.secondary)
//        }
//        .padding(12)
//        .background(Color.red.opacity(0.1))
//        .cornerRadius(12)
//        .overlay(
//            RoundedRectangle(cornerRadius: 12)
//                .stroke(Color.red.opacity(0.3), lineWidth: 1)
//        )
//    }
//    
//    private var normalContentView: some View {
//        HStack(spacing: 12) {
//            // Download button on the left
//            Button(action: openFile) {
//                Image(systemName: "arrow.down.circle.fill")
//                    .font(.system(size: 32))
//                    .foregroundColor(isCurrentUser ? .white : .blue)
//            }
//            .buttonStyle(PlainButtonStyle())
//            
//            //                // File icon in the middle
//            //                Image(systemName: fileIcon)
//            //                    .font(.system(size: 32))
//            //                    .foregroundColor(isCurrentUser ? .white : .blue)
//                            
//            // File info
//            VStack(alignment: .leading, spacing: 4) {
//                Text(fileName)
//                    .font(.system(size: 14, weight: .medium))
//                    .lineLimit(2)
//                
//                Text(fileExtension)
//                    .font(.system(size: 12))
//                    .opacity(0.7)
//            }
//        }
//        .padding(12)
//        .background(bubbleBackground)
//        .foregroundColor(bubbleForeground)
//        .cornerRadius(12)
//        .contextMenu {
//            Button(action: {
//                UIPasteboard.general.string = fileUrl
//            }) {
//                Label("Copy URL", systemImage: "doc.on.doc")
//            }
//            
//            Button(action: openFile) {
//                Label("Open File", systemImage: "arrow.down.circle")
//            }
//        }
//    }
//    
//    private func openFile() {
//        guard let url = URL(string: fileUrl) else { return }
//        UIApplication.shared.open(url)
//    }
//}
