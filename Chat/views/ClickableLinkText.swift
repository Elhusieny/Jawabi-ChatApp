//
//  ClickableLinkText.swift
//  Chat
//
//  Created by Ahmed Elhussieny on 01/02/2026.
//

import SwiftUI
// MARK: - Clickable Link View
struct ClickableLinkText: View {
    let text: String
    let bubbleBackground: LinearGradient
    let bubbleForeground: Color
    
    var body: some View {
        if let url = URL(string: text), text.hasPrefix("http") {
            // It's a pure URL - make it clickable
            Link(destination: url) {
                HStack(spacing: 8) {
                    Image(systemName: "link")
                        .font(.system(size: 14))
                    
                    Text(displayText)
                        .underline()
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(bubbleBackground)
            .foregroundColor(bubbleForeground)
            .cornerRadius(12)
        } else {
            // Regular text
            Text(text)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(bubbleBackground)
                .foregroundColor(bubbleForeground)
                .cornerRadius(12)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private var displayText: String {
        // Shorten very long URLs for display
        if text.count > 60 {
            return text.prefix(57) + "..."
        }
        return text
    }
}
