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

    func test_nearbyLoadLooksUpForecastSeaAndInsightsByCoordinates() async {
        let viewModel = DashboardViewModel(apiClient: APIClient(session: MockURLProtocol.makeMockedSession()))
        let body = unavailable
        let paths = LockedPaths()
        MockURLProtocol.requestHandler = { request in
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            if query.first(where: { $0.name == "lat" })?.value == "38.7223",
               query.first(where: { $0.name == "lon" })?.value == "-9.1393" {
                paths.append(request.url!.path)
            }
            return (503, body)
        }

        await viewModel.loadWeather(
            for: "São Sebastião da Pedreira, PT", isFromNearbyLocation: true, nearbyWeather: nearbyWeather,
            coordinate: GeoCoordinate(latitude: 38.7223, longitude: -9.1393))

        XCTAssertEqual(Set(paths.values),
                       ["/api/v1/weather/forecast", "/api/v1/weather/marine", "/api/v1/weather/insights"])
    }
}

/// The mocked session calls its handler off the main actor, concurrently for the three lookups.
private final class LockedPaths: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []
    var values: [String] { lock.withLock { storage } }
    func append(_ path: String) { lock.withLock { storage.append(path) } }
}
