import XCTest
@testable import WeatherApp_iOS

@MainActor
final class DashboardViewModelTests: XCTestCase {
    private let unavailable = Data("""
        {"timestamp":"2026-10-02T12:00:00Z","status":503,"error":"Unavailable",
         "message":"Provider unavailable","path":"/api/v1/weather"}
        """.utf8)

    private var nearbyWeather: WeatherResponse {
        WeatherResponse(city: "Lisboa", country: "Portugal", temperature: 20, feelsLike: 20,
                        humidity: 60, windSpeed: 10, description: "Clear sky", units: .metric,
                        provider: "open-weather-map", observedAt: Date(), fromCache: false)
    }

    func test_nearbyWeatherDoesNotRequireAnotherCityLookup() async {
        let viewModel = DashboardViewModel(apiClient: APIClient(session: MockURLProtocol.makeMockedSession()))
        let body = unavailable
        MockURLProtocol.requestHandler = { request in
            XCTAssertNotEqual(request.url?.path, "/api/v1/weather")
            return (503, body)
        }
        let nearby = nearbyWeather
        await viewModel.loadWeather(for: "Lisboa, Portugal", nearbyWeather: nearby)

        XCTAssertEqual(viewModel.weather, nearby)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNotNil(viewModel.forecastErrorMessage)
        XCTAssertFalse(viewModel.isLoading)
    }

    func test_failedSearchClearsDataFromThePreviousCity() async {
        let viewModel = DashboardViewModel(apiClient: APIClient(session: MockURLProtocol.makeMockedSession()))
        let body = unavailable
        MockURLProtocol.requestHandler = { _ in (503, body) }
        await viewModel.loadWeather(for: "Lisboa, Portugal", nearbyWeather: nearbyWeather)
        XCTAssertNotNil(viewModel.weather)

        await viewModel.loadWeather(for: "Porto, Portugal")

        XCTAssertNil(viewModel.weather)
        XCTAssertNil(viewModel.forecast)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
    }
}
