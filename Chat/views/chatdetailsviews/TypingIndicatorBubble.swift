////
////  TypingIndicatorBubble.swift
////  Chat
////
////  Created by Ahmed Elhussieny on 02/06/2026.
////
//
//
//import SwiftUI
//// Typing indicator bubble
//struct TypingIndicatorBubble: View {
//    let userName: String
//    let gradientAnimation: Bool
//    
//    var body: some View {
//        HStack(alignment: .bottom, spacing: 8) {
//            VStack(alignment: .leading, spacing: 2) {
//                HStack(alignment: .bottom, spacing: 6) {
//                    HStack(spacing: 8) {
//                        Text("\(userName) is typing")
//                            .font(.system(size: 13))
//                            .foregroundColor(.secondary)
//                        
//                        HStack(spacing: 3) {
//                            ForEach(0..<3) { index in
//                                Circle()
//                                    .fill(
//                                        LinearGradient(
//                                            colors: [.blue, .purple],
//                                            startPoint: .top,
//                                            endPoint: .bottom
//                                        )
//                                    )
//                                    .frame(width: 6, height: 6)
//                                    .opacity(gradientAnimation ? 1.0 : 0.3)
//                                    .animation(
//                                        Animation.easeInOut(duration: 0.6)
//                                            .repeatForever(autoreverses: true)
//                                            .delay(Double(index) * 0.2),
//                                        value: gradientAnimation
//                                    )
//                            }
//                        }
//                    }
//                    .padding(.horizontal, 12)
//                    .padding(.vertical, 8)
//                    .background(
//                        LinearGradient(
//                            colors: [Color(.systemGray5), Color(.systemGray4)],
//                            startPoint: .topLeading,
//                            endPoint: .bottomTrailing
//                        )
//                    )
//                    .cornerRadius(12)
//                }
//            }
//            
//            Spacer(minLength: 50)
//        }
//        .padding(.horizontal, 4)
//    }
//}
