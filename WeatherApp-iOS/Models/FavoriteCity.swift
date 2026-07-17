import Foundation

/// Request body for `POST /api/v1/weather/favorites`.
struct AddFavoriteRequest: Encodable {
    let city: String
}

/// Entry shape for both `GET` and `POST /api/v1/weather/favorites`.
struct FavoriteCity: Decodable, Equatable, Identifiable {
    let city: String
    let createdAt: Date

    var id: String { city }

    enum CodingKeys: String, CodingKey {
        case city, createdAt
    }

    init(city: String, createdAt: Date) {
        self.city = city
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        city = try container.decode(String.self, forKey: .city)
        let raw = try container.decode(String.self, forKey: .createdAt)
        guard let parsed = BackendDateFormatters.parseInstant(raw) else {
            throw DateDecodingError.invalidInstant(raw)
        }
        createdAt = parsed
    }
}
