import Foundation

/// Body for both `/auth/register` and `/auth/login`.
struct AuthRequest: Encodable {
    let email: String
    let password: String
}

/// Shared response shape returned by `/auth/register` and `/auth/login`.
struct AuthResponse: Decodable {
    let token: String
    let tokenType: String
    let expiresInSeconds: Int
}
