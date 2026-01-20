//
//  CachingAsyncImage.swift
//  Chat
//
//  Created by Ahmed Elhussieny on 08/12/2025.
//


import SwiftUI

struct CachingAsyncImage<Content>: View where Content: View {
    let url: URL?
    let scale: CGFloat
    let transaction: Transaction
    let content: (AsyncImagePhase) -> Content
    
    @State private var imageData: Data?
    @State private var isLoading = false
    
    init(url: URL?, scale: CGFloat = 1.0, transaction: Transaction = Transaction(), @ViewBuilder content: @escaping (AsyncImagePhase) -> Content) {
        self.url = url
        self.scale = scale
        self.transaction = transaction
        self.content = content
    }
    
    var body: some View {
        if let imageData = imageData, let uiImage = UIImage(data: imageData) {
            content(.success(Image(uiImage: uiImage)))
        } else if isLoading {
            content(.empty)
        } else {
            content(.empty)
                .onAppear {
                    loadImage()
                }
                .onChange(of: url) { _ in
                    loadImage()
                }
        }
    }
    
    private func loadImage() {
        guard let url = url else { return }
        
        // Check cache first
        if let cachedData = ImageCache.shared.get(forKey: url.absoluteString) {
            self.imageData = cachedData
            return
        }
        
        isLoading = true
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let data = data, let _ = UIImage(data: data) {
                    self.imageData = data
                    ImageCache.shared.set(data, forKey: url.absoluteString)
                }
            }
        }.resume()
    }
}

class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, NSData>()
    
    private init() {}
    
    func get(forKey key: String) -> Data? {
        return cache.object(forKey: key as NSString) as Data?
    }
    
    func set(_ data: Data, forKey key: String) {
        cache.setObject(data as NSData, forKey: key as NSString)
    }
    
    func remove(forKey key: String) {
        cache.removeObject(forKey: key as NSString)
    }
    
    func clear() {
        cache.removeAllObjects()
    }
}