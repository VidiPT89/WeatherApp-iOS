import XCTest
@testable import WeatherApp_iOS

/// Covers `FavoritesViewModel.addFavorite(city:)` -- the entry point now fed
/// exclusively by `CitySearchField`'s autocomplete suggestions rather than a
/// free-text field (see `FavoritesView`), including the friendly 409
/// duplicate-favorite message.
@MainActor
final class FavoritesViewModelTests: XCTestCase {
    private func favoriteBody(city: String) -> Data {
        """
        {"city": "\(city)", "createdAt": "2024-01-01T12:00:00Z"}
        """.data(using: .utf8)!
    }

    private func errorBody(status: Int, message: String) -> Data {
        """
        {
          "timestamp": "2024-01-01T12:00:00Z", "status": \(status), "error": "Error",
          "message": "\(message)", "path": "/api/v1/weather/favorites"
        }
        """.data(using: .utf8)!
    }

    private func makeViewModel() async -> FavoritesViewModel {
        let client = APIClient(session: MockURLProtocol.makeMockedSession())
        await client.setTokens(access: "test-token", refresh: "test-refresh-token")
        return FavoritesViewModel(apiClient: client)
    }

    func test_addFavorite_appendsTheReturnedCityAndClearsNoError() async throws {
        let viewModel = await makeViewModel()

        let body = favoriteBody(city: "Porto")
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            return (201, body)
        }

        await viewModel.addFavorite(city: "Porto")

        XCTAssertEqual(viewModel.favorites.map(\.city), ["Porto"])
        XCTAssertEqual(viewModel.addFeedback, "Porto adicionada aos favoritos.")
    }

    func test_addFavorite_showsFriendlyMessage_on409Duplicate() async throws {
        let viewModel = await makeViewModel()

        let duplicateBody = errorBody(status: 409, message: "Favorite already exists")
        MockURLProtocol.requestHandler = { _ in (409, duplicateBody) }

        await viewModel.addFavorite(city: "Lisboa")

        XCTAssertTrue(viewModel.favorites.isEmpty)
        XCTAssertEqual(viewModel.addFeedback, "Lisboa já está nos teus favoritos.")
    }

    func test_addFavorite_ignoresBlankInput() async throws {
        let viewModel = await makeViewModel()

        MockURLProtocol.requestHandler = { _ in
            XCTFail("A blank city name should never reach the network")
            return (500, Data())
        }

        await viewModel.addFavorite(city: "   ")

        XCTAssertTrue(viewModel.favorites.isEmpty)
        XCTAssertNil(viewModel.addFeedback)
    }
}
