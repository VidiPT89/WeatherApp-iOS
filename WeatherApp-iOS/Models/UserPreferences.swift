import Foundation

/// `GET`/`POST /api/v1/user/preferences` request/response body.
struct UserPreferences: Codable, Equatable {
    let units: Units
}
