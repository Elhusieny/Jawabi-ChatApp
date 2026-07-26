//
//  TextBubbleView.swift
//  Chat
//
//  Created by Ahmed Elhussieny on 25/06/2026.
//

import SwiftUI


struct TextBubbleView: View {
    let text: String
    let isCurrentUser: Bool
    let bubbleBackground: LinearGradient
    let bubbleForeground: Color
    let timestampContent: AnyView

    // Measure if text fits on one short line
    private var isShortText: Bool {
        let font = UIFont.systemFont(ofSize: 17)
        let maxInlineWidth: CGFloat = 180  // adjust if needed
        let size = (text as NSString).boundingRect(
            with: CGSize(width: maxInlineWidth, height: 44),
            options: .usesLineFragmentOrigin,
            attributes: [.font: font],
            context: nil
        )
        return size.height <= 24  // single line only
    }

    var body: some View {
        Group {
            if isShortText {
                // ── Short text: timestamp sits inline to the right ──
                HStack(alignment: .bottom, spacing: 4) {
                    Text(text)
                        .font(.body)
                        .foregroundColor(bubbleForeground)
                        .fixedSize(horizontal: false, vertical: true)

                    timestampContent
                        .layoutPriority(-1)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(bubbleBackground)
                .cornerRadius(12)
            } else {
                // ── Long text: timestamp on its own line, right-aligned ──
                VStack(alignment: .leading, spacing: 4) {
                    Text(text)
                        .font(.body)
                        .foregroundColor(bubbleForeground)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack {
                        Spacer()
                        timestampContent
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(bubbleBackground)
                .cornerRadius(12)
            }
        }
        .contextMenu {
            Button(action: { UIPasteboard.general.string = text }) {
                Label("Copy", systemImage: "doc.on.doc")
            }
        }
    }
}
