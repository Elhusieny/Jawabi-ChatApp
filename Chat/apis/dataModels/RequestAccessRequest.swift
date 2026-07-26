struct RequestAccessRequest {
    let userName: String
    let email: String
    let displayName: String
    let phoneNumber: String
    let password: String
    let companyName: String
    let profilePicture: Data?
    let serverUrl: String?
}