import XCTest
@testable import WeatherApp_iOS

final class CompareResponseTests: XCTestCase {
    private func makeWeather(temperature: Double, provider: String) -> WeatherResponse {
        WeatherResponse(
            city: "Lisboa", country: "Portugal", temperature: temperature, feelsLike: temperature,
            humidity: 50, windSpeed: 5, description: "clear", units: .metric,
            provider: provider, observedAt: .now, fromCache: false
        )
    }

    func test_averageTemperature_isNil_whenFewerThanTwoSucceed() {
        let response = CompareResponse(city: "Lisboa", results: [
            ProviderComparisonResult(provider: "open-meteo", success: true, weather: makeWeather(temperature: 20, provider: "open-meteo"), errorMessage: nil),
            ProviderComparisonResult(provider: "open-weather-map", success: false, weather: nil, errorMessage: "Provider unavailable")
        ])

        XCTAssertNil(response.averageTemperature)
    }

    func test_averageTemperature_averagesSuccessfulProvidersOnly() {
        let response = CompareResponse(city: "Lisboa", results: [
            ProviderComparisonResult(provider: "open-meteo", success: true, weather: makeWeather(temperature: 20, provider: "open-meteo"), errorMessage: nil),
            ProviderComparisonResult(provider: "open-weather-map", success: true, weather: makeWeather(temperature: 24, provider: "open-weather-map"), errorMessage: nil)
        ])

        XCTAssertEqual(response.averageTemperature, 22.0)
    }

    func test_isPrimaryProvider_matchesOpenMeteoOnly() {
        let primary = ProviderComparisonResult(provider: "open-meteo", success: true, weather: nil, errorMessage: nil)
        let secondary = ProviderComparisonResult(provider: "open-weather-map", success: true, weather: nil, errorMessage: nil)

        XCTAssertTrue(primary.isPrimaryProvider)
        XCTAssertFalse(secondary.isPrimaryProvider)
    }
}
