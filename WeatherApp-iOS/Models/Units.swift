import Foundation

/// Temperature unit system used across the API. Mirrors the backend's
/// `units` string field ("metric" | "imperial").
enum Units: String, Codable, CaseIterable, Identifiable {
    case metric
    case imperial

    var id: String { rawValue }

    var temperatureSymbol: String {
        switch self {
        case .metric: return "°C"
        case .imperial: return "°F"
        }
    }

    var windSpeedSymbol: String {
        switch self {
        case .metric: return "km/h"
        case .imperial: return "mph"
        }
    }

    var displayName: String {
        switch self {
        case .metric: return "Métrico (°C)"
        case .imperial: return "Imperial (°F)"
        }
    }
}
