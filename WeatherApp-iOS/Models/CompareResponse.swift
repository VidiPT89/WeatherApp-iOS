import Foundation

/// One provider's result within `GET /api/v1/weather/compare`.
struct ProviderComparisonResult: Decodable, Equatable, Identifiable {
    let provider: String
    let success: Bool
    let weather: WeatherResponse?
    let errorMessage: String?

    var id: String { provider }

    var isPrimaryProvider: Bool { provider == WeatherResponse.primaryProvider }
}

/// `GET /api/v1/weather/compare` response.
struct CompareResponse: Decodable, Equatable {
    let city: String
    let results: [ProviderComparisonResult]

    /// Average temperature across providers that returned a successful result.
    /// `nil` when fewer than two providers succeeded (nothing meaningful to average).
    var averageTemperature: Double? {
        let successfulTemperatures = results.compactMap { $0.success ? $0.weather?.temperature : nil }
        guard successfulTemperatures.count >= 2 else { return nil }
        return successfulTemperatures.reduce(0, +) / Double(successfulTemperatures.count)
    }
}
