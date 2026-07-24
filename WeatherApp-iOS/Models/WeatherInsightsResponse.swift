import Foundation

struct MoonPhaseInfo: Decodable, Equatable {
    let phase: String
    let illuminationPercent: Int
}

/// `GET /api/v1/weather/insights` response: a handful of derived "nice to
/// know" indicators computed server-side from data already fetched for the
/// dashboard. `fishingConditionLabel` is `nil` for inland/non-coastal cities
/// with no marine data; the other three apply to any city.
struct WeatherInsightsResponse: Decodable, Equatable {
    let city: String
    let country: String
    let moonPhase: MoonPhaseInfo
    let uvRiskLabel: String
    let outdoorActivityScore: Int
    let outdoorActivityLabel: String
    let fishingConditionLabel: String?
}
