import Foundation

/// Mirrors the backend's `Role` enum ("user" | "admin").
enum UserRole: String, Codable {
    case user
    case admin
}

/// One entry of `GET /api/v1/admin/users`, and the shape of
/// `GET /api/v1/user/me` for the caller's own account.
struct UserAccount: Decodable, Equatable, Identifiable {
    let id: Int
    let email: String
    let role: UserRole
    let units: Units
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, email, role, units, createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        role = try container.decode(UserRole.self, forKey: .role)
        units = try container.decode(Units.self, forKey: .units)
        let raw = try container.decode(String.self, forKey: .createdAt)
        guard let parsed = BackendDateFormatters.parseInstant(raw) else {
            throw DateDecodingError.invalidInstant(raw)
        }
        createdAt = parsed
    }
}
