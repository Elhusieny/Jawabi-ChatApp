//
//  ScanningMessageView.swift
//  Chat
//
//  Created by Ahmed Elhussieny on 02/06/2026.
//


import SwiftUI

/// A view that displays a temporary message while a file is being scanned for viruses/malware
/// This view provides visual feedback during the file scanning process before the actual file message is displayed


// MARK: - Scanning Message View
struct ScanningMessageView: View {
    let fileName: String
    let isCurrentUser: Bool
    
    private var bubbleBackground: LinearGradient {
        if isCurrentUser {
            return LinearGradient(
                colors: [.blue, .purple],
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
    
    private var bubbleForeground: Color {
        isCurrentUser ? .white : .primary
    }
    
    @State private var scanningProgress: Double = 0
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // Scanning icon with animation
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 2)
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                        .rotationEffect(.degrees(isAnimating ? 360 : 0))
                        .animation(
                            Animation.linear(duration: 2)
                                .repeatForever(autoreverses: false),
                            value: isAnimating
                        )
                }
                .onAppear {
                    isAnimating = true
                    startProgressAnimation()
                }
                
                // File info
                VStack(alignment: .leading, spacing: 4) {
                    Text(fileName)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(2)
                        .foregroundColor(bubbleForeground)
                    
                    Text("Scanning for viruses...")
                        .font(.system(size: 11))
                        .foregroundColor(bubbleForeground.opacity(0.7))
                    
                    // Progress indicator
                    ProgressView(value: scanningProgress, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(width: 120)
                        .padding(.top, 2)
                }
                
                Spacer()
                
                // Status indicator
                VStack {
                    Text("⏳")
                        .font(.system(size: 20))
                    Text("Scanning")
                        .font(.system(size: 9))
                        .foregroundColor(bubbleForeground.opacity(0.6))
                }
            }
            .padding(12)
            .frame(maxWidth: 280)
            .background(bubbleBackground)
            .cornerRadius(12)
        }
    }
    
    private func startProgressAnimation() {
        // Animate progress from 0 to 0.8 (simulating scan progress)
        withAnimation(Animation.easeInOut(duration: 1).repeatForever(autoreverses: false)) {
            scanningProgress = 0.8
        }
    }
}
