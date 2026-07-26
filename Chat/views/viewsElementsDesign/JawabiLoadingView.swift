// JawabiLoadingView.swift
import SwiftUI

struct JawabiLoadingView: View {
    let message: String
    
    init(_ message: String = "Loading...") {
        self.message = message
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(Color.jawabiPrimary)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(Color.jawabiPrimary)
        }
    }
}