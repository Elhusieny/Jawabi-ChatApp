struct GroupMemberDTO: Codable {
    let id: String
    let name: String
    let pictureUrl: String?
    let role: String // "Admin" or "Member"

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case pictureUrl = "PictureUrl"
        case role = "Role"
    }
}

struct GroupMembersResponse: Codable {
    let result: [GroupMemberDTO]
    enum CodingKeys: String, CodingKey {
        case result = "Result"
    }
}

extension AdminManagementService {
    func fetchGroupMembers(chatId: Int) -> AnyPublisher<[GroupMemberDTO], Error> {
        guard let url = URL(string: "\(Utilities.baseURL)/api/Chat/usersOfGroup/\(chatId)") else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        var request = URLRequest(url: url)
        if let token = UserDefaults.standard.string(forKey: "authToken") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: GroupMembersResponse.self, decoder: JSONDecoder())
            .map(\.result)
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}