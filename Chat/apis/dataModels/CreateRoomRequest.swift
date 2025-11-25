//
//  CreateRoomRequest.swift
//  Chat
//
//  Created by Ahmed Elhussieny on 23/11/2025.
//


import Foundation

// MARK: - Create Room Request
struct CreateRoomRequest {
    let name: String
    let chatPicture: String?
    let memberIds: [String]
}

// MARK: - Create Room Response
import Foundation

// MARK: - Create Room Response
struct CreateRoomResponse: Codable {
    let message: String?
    let picture: String?
    let roomId: Int? // If your backend returns room ID
    let success: Bool? // If your backend returns success flag
    
    // Computed property for easier success checking
    var isSuccess: Bool {
        return success == true || message?.lowercased().contains("success") == true
    }
}
