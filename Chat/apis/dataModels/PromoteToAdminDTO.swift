// Add these structs at the top of SignalRService.swift (outside the class)
struct UserPromotedData: Codable {
    let chatId: Int
    let userId: String
    let newRole: String
}
