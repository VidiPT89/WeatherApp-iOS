import Foundation

/// One entry of `GET /api/v1/weather/history`.
struct HistoryEntry: Decodable, Equatable, Identifiable {
    let city: String
    let units: Units
    let searchedAt: Date

    var id: String { "\(city)-\(units.rawValue)-\(searchedAt.timeIntervalSince1970)" }

    enum CodingKeys: String, CodingKey {
        case city, units, searchedAt
    }

    init(city: String, units: Units, searchedAt: Date) {
        self.city = city
        self.units = units
        self.searchedAt = searchedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        city = try container.decode(String.self, forKey: .city)
        units = try container.decode(Units.self, forKey: .units)
        let raw = try container.decode(String.self, forKey: .searchedAt)
        guard let parsed = BackendDateFormatters.parseInstant(raw) else {
            throw DateDecodingError.invalidInstant(raw)
        }
        searchedAt = parsed
    }
}
