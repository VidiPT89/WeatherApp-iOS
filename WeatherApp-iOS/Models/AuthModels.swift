import Foundation

/// Body for both `/auth/register` and `/auth/login`.
struct AuthRequest: Encodable {
    let email: String
    let password: String
}

/// Shared response shape returned by `/auth/register`, `/auth/login`, and `/auth/refresh`.
struct AuthResponse: Decodable {
    let token: String
    let tokenType: String
    let expiresInSeconds: Int
    let refreshToken: String
}

/// Body for `/auth/refresh` and `/auth/logout` — both just take the refresh token.
struct RefreshRequest: Encodable {
    let refreshToken: String
}
