import Foundation

/// Downloads chat/group avatar bytes, de-duplicating concurrent requests
/// for the same URL (e.g. several rows sharing one group photo).
actor ChatAvatarImageLoader {
    static let shared = ChatAvatarImageLoader()

    private var inFlight: [String: Task<Data?, Never>] = [:]

    func loadData(from urlString: String) async -> Data? {
        if let existing = inFlight[urlString] {
            return await existing.value
        }

        let task = Task<Data?, Never> {
            guard let url = URL(string: urlString) else { return nil }
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    return data
                }
                return nil
            } catch {
                return nil
            }
        }

        inFlight[urlString] = task
        let result = await task.value
        inFlight[urlString] = nil
        return result
    }
}