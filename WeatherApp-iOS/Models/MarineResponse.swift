import Foundation

/// A single high/low tide event, derived server-side from Open-Meteo's
/// hourly sea-level-height series — an estimate, not an official tide table.
struct TideEvent: Decodable, Equatable {
    let type: String
    let time: String

    var isHigh: Bool { type == "high" }
}

/// `GET /api/v1/weather/marine` response: water temperature, swell and
/// estimated tide times for a city. All fields are `nil`/empty (not an
/// error, still HTTP 200) for inland/non-coastal cities; views should show a
/// "no sea data" placeholder in that case.
struct MarineResponse: Decodable, Equatable {
    let city: String
    let country: String
    let units: Units
    let provider: String
    let fromCache: Bool
    let waterTemperature: Double?
    let waveHeightMeters: Double?
    let waveDirectionDegrees: Double?
    let wavePeriodSeconds: Double?
    let tideEvents: [TideEvent]

    /// Whether there's anything to show — `false` when every data field is `nil`.
    var hasData: Bool {
        waterTemperature != nil || waveHeightMeters != nil || waveDirectionDegrees != nil || wavePeriodSeconds != nil
    }
}
