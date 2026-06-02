////
////  MessageTimestampView.swift
////  Chat
////
////  Created by Ahmed Elhussieny on 02/06/2026.
////
//
//
//import SwiftUI
//
//// MARK: - MessageTimestampView
///// Reusable inline timestamp + delivery-status checkmark shown inside every bubble.
//struct MessageTimestampView: View {
//    let message: Message
//    let isCurrentUser: Bool
//    let checkmarkState: MessageCheckmarkState
//
//    var body: some View {
//        HStack(spacing: 3) {
//            Text(message.formattedTime)          // "3:45 PM"  ← uses AM/PM helper
//                .font(.system(size: 11, weight: .medium))
//                .foregroundColor(isCurrentUser ? .white.opacity(0.7) : .gray)
//
//            if isCurrentUser {
//                MessageCheckmarkView(state: checkmarkState)
//            }
//        }
//    }
//}
//
//// MARK: - Checkmark state
//enum MessageCheckmarkState {
//    case sent
//    case delivered
//    case seen
//}
//
//// MARK: - MessageCheckmarkView
//struct MessageCheckmarkView: View {
//    let state: MessageCheckmarkState
//
//    var body: some View {
//        HStack(spacing: -4) {
//            switch state {
//            case .sent:
//                Image(systemName: "checkmark")
//                    .font(.system(size: 11))
//                    .foregroundColor(.gray)
//
//            case .delivered:
//                Image(systemName: "checkmark")
//                    .font(.system(size: 11))
//                    .foregroundColor(.gray)
//                Image(systemName: "checkmark")
//                    .font(.system(size: 11))
//                    .foregroundColor(.gray)
//                    .offset(x: -3)
//
//            case .seen:
//                Image(systemName: "checkmark")
//                    .font(.system(size: 11))
//                    .foregroundColor(.blue)
//                Image(systemName: "checkmark")
//                    .font(.system(size: 11))
//                    .foregroundColor(.blue)
//                    .offset(x: -3)
//            }
//        }
//        .frame(width: state == .sent ? 10 : 16, height: 10)
//    }
//}
//
//// MARK: - Status Tooltip
//struct MessageStatusTooltipView: View {
//    let statusText: String
//    let seenByUsers: [String]
//
//    var body: some View {
//        VStack(spacing: 2) {
//            Text(statusText)
//                .font(.system(size: 10))
//                .padding(4)
//                .background(Color.black.opacity(0.7))
//                .foregroundColor(.white)
//                .cornerRadius(4)
//
//            if !seenByUsers.isEmpty {
//                Text("Seen by:")
//                    .font(.system(size: 9))
//                    .padding(.top, 2)
//
//                ForEach(seenByUsers, id: \.self) { user in
//                    Text(user)
//                        .font(.system(size: 9))
//                        .padding(2)
//                        .background(Color.black.opacity(0.5))
//                        .foregroundColor(.white)
//                        .cornerRadius(3)
//                }
//            }
//        }
//        .padding(6)
//        .background(Color.black.opacity(0.8))
//        .foregroundColor(.white)
//        .cornerRadius(6)
//        .padding(.bottom, 25)
//        .transition(.opacity)
//    }
//}
