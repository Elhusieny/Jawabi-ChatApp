////
////  TextMessageBubble.swift
////  Chat
////
////  Created by Ahmed Elhussieny on 02/06/2026.
////
//
//
//import SwiftUI
//
//// MARK: - TextMessageBubble
///// Shows a plain-text or URL message bubble.
///// For short text (≈ one word / short phrase) the timestamp stays on the SAME line.
///// For longer text the timestamp sits bottom-trailing inside the bubble (with trailing padding).
//struct TextMessageBubble: View {
//    let message: Message
//    let isCurrentUser: Bool
//    let bubbleBackground: LinearGradient
//    let bubbleForeground: Color
//    let timestampView: AnyView          // injected from UniversalMessageBubble
//
//    // Threshold: if the displayed text is shorter than this many characters
//    // we try to keep the timestamp on the same line.
//    private let inlineThreshold = 30
//
//    var body: some View {
//        let text = message.displayText
//
//        if text.hasPrefix("http://") || text.hasPrefix("https://") {
//            urlBubble(text: text)
//        } else if text.count <= inlineThreshold {
//            shortTextBubble(text: text)
//        } else {
//            longTextBubble(text: text)
//        }
//    }
//
//    // ── URL bubble ───────────────────────────────────────────────────────────
//    @ViewBuilder
//    private func urlBubble(text: String) -> some View {
//        ZStack(alignment: .bottomTrailing) {
//            ClickableLinkText(
//                text: text,
//                bubbleBackground: bubbleBackground,
//                bubbleForeground: bubbleForeground
//            )
//            .contextMenu {
//                Button(action: { UIPasteboard.general.string = text }) {
//                    Label("Copy Link", systemImage: "doc.on.doc")
//                }
//                if let url = URL(string: text) {
//                    Button(action: { UIApplication.shared.open(url) }) {
//                        Label("Open in Browser", systemImage: "safari")
//                    }
//                }
//            }
//            timestampView.padding(.trailing, 8)
//        }
//    }
//
//    // ── Short text: timestamp on same line ───────────────────────────────────
//    @ViewBuilder
//    private func shortTextBubble(text: String) -> some View {
//        HStack(alignment: .bottom, spacing: 6) {
//            Text(text)
//                .font(.body)
//                .foregroundColor(bubbleForeground)
//
//            timestampView
//        }
//        .padding(.horizontal, 12)
//        .padding(.vertical, 8)
//        .background(bubbleBackground)
//        .cornerRadius(12)
//        .contextMenu {
//            Button(action: { UIPasteboard.general.string = text }) {
//                Label("Copy", systemImage: "doc.on.doc")
//            }
//        }
//    }
//
//    // ── Long text: timestamp inside bottom-trailing ──────────────────────────
//    @ViewBuilder
//    private func longTextBubble(text: String) -> some View {
//        ZStack(alignment: .bottomTrailing) {
//            // Extra trailing space reserves room so the last line of text
//            // never overlaps the timestamp.
//            Text(text + "          ")
//                .padding(.horizontal, 12)
//                .padding(.vertical, 8)
//                .background(bubbleBackground)
//                .foregroundColor(bubbleForeground)
//                .cornerRadius(12)
//                .fixedSize(horizontal: false, vertical: true)
//                .contextMenu {
//                    Button(action: { UIPasteboard.general.string = text }) {
//                        Label("Copy", systemImage: "doc.on.doc")
//                    }
//                }
//
//            timestampView
//                .padding(.trailing, 8)
//                .padding(.bottom, 6)
//        }
//    }
//}
