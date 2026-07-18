import Foundation

/// `GET /api/v1/weather/marine` response: water temperature and swell for a
/// city. NOT tide times — the backend doesn't provide those. All four data
/// fields are `nil` (not an error, still HTTP 200) for inland/non-coastal
/// cities; views should show a "no sea data" placeholder in that case.
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

    /// Whether there's anything to show — `false` when every data field is `nil`.
    var hasData: Bool {
        waterTemperature != nil || waveHeightMeters != nil || waveDirectionDegrees != nil || wavePeriodSeconds != nil
    }
}
