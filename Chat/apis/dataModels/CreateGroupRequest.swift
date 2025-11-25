import Foundation

//// MARK: - Create Room Request
//struct CreateRoomRequest {
//    let name: String
//    let chatPicture: String?
//    let memberIds: [String]
//}
//
//// MARK: - Create Room Response
//struct CreateRoomResponse: Codable {
//    let success: Bool
//    let roomId: Int?
//    let message: String?
//    let error: String?
//}

// MARK: - Join Room Response
struct JoinRoomResponse: Codable {
    let result: String?
    let success: Bool?
    let message: String?
    let error: String?
}

// MARK: - Group Room Model
struct GroupRoom: Codable, Identifiable {
    let id: Int
    let name: String
    let pictureUrl: String?
    let memberCount: Int
    let createdBy: String
    let createdAt: String
    let members: [RoomMember]
    
    var displayPictureUrl: String {
        if let pictureUrl = pictureUrl, !pictureUrl.isEmpty {
            if pictureUrl.hasPrefix("http") {
                return pictureUrl
            } else {
                return "http://184.174.37.115:8444\(pictureUrl)"
            }
        }
        return "http://184.174.37.115:8444/images/default-group.png"
    }
}

// MARK: - Room Member
struct RoomMember: Codable, Identifiable {
    let id: String
    let username: String
    let profilePicture: String?
    let joinedAt: String
    
    var displayProfilePicture: String {
        if let profilePicture = profilePicture, !profilePicture.isEmpty {
            if profilePicture.hasPrefix("http") {
                return profilePicture
            } else {
                return "http://184.174.37.115:8444\(profilePicture)"
            }
        }
        return "http://184.174.37.115:8444/images/default-avatar.png"
    }
}
