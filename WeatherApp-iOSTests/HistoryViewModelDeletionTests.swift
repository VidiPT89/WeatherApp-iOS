import XCTest
@testable import WeatherApp_iOS

@MainActor
final class HistoryViewModelDeletionTests: XCTestCase {
    private func historyBody() -> Data {
        """
        [
          {"id": 1, "city": "Lisboa", "units": "metric", "searchedAt": "2024-01-02T10:00:00Z"},
          {"id": 2, "city": "Porto", "units": "imperial", "searchedAt": "2024-01-01T10:00:00Z"}
        ]
        """.data(using: .utf8)!
    }

    private func errorBody(status: Int, message: String) -> Data {
        """
        {
          "timestamp": "2024-01-01T12:00:00Z", "status": \(status), "error": "Error",
          "message": "\(message)", "path": "/api/v1/weather/history"
        }
        """.data(using: .utf8)!
    }

    private func makeViewModel() async -> HistoryViewModel {
        let client = APIClient(session: MockURLProtocol.makeMockedSession())
        await client.setTokens(access: "test-token", refresh: "test-refresh-token")
        return HistoryViewModel(apiClient: client)
    }

    func test_deleteEntry_removesItFromTheListOnSuccess() async throws {
        let viewModel = await makeViewModel()

        let historyBody = historyBody()
        MockURLProtocol.requestHandler = { request in
            if request.httpMethod == "GET" { return (200, historyBody) }
            return (204, Data())
        }
        await viewModel.loadHistory()
        XCTAssertEqual(viewModel.entries.count, 2)

        let target = viewModel.entries.first { $0.city == "Lisboa" }!
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "DELETE")
            XCTAssertTrue(request.url?.path.hasSuffix("/history/\(target.id)") ?? false)
            return (204, Data())
        }

        await viewModel.deleteEntry(target)

        XCTAssertEqual(viewModel.entries.count, 1)
        XCTAssertFalse(viewModel.entries.contains { $0.id == target.id })
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.deletingEntryId)
    }

    func test_deleteEntry_surfacesErrorAndKeepsEntry_onFailure() async throws {
        let viewModel = await makeViewModel()

        let historyBody = historyBody()
        MockURLProtocol.requestHandler = { request in
            if request.httpMethod == "GET" { return (200, historyBody) }
            return (204, Data())
        }
        await viewModel.loadHistory()
        let target = viewModel.entries.first!

        let notFoundBody = errorBody(status: 404, message: "History entry not found")
        MockURLProtocol.requestHandler = { _ in (404, notFoundBody) }

        await viewModel.deleteEntry(target)

        XCTAssertEqual(viewModel.entries.count, 2, "Entry should remain in the list when the delete fails")
        XCTAssertEqual(viewModel.errorMessage, "History entry not found")
        XCTAssertNil(viewModel.deletingEntryId)
    }

    func test_clearAll_emptiesTheListOnSuccess() async throws {
        let viewModel = await makeViewModel()

        let historyBody = historyBody()
        MockURLProtocol.requestHandler = { request in
            if request.httpMethod == "GET" { return (200, historyBody) }
            return (204, Data())
        }
        await viewModel.loadHistory()
        XCTAssertEqual(viewModel.entries.count, 2)

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "DELETE")
            XCTAssertTrue(request.url?.path.hasSuffix("/weather/history") ?? false)
            return (204, Data())
        }

        await viewModel.clearAll()

        XCTAssertTrue(viewModel.entries.isEmpty)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isClearing)
    }

    func test_clearAll_surfacesError_onFailure() async throws {
        let viewModel = await makeViewModel()

        let historyBody = historyBody()
        MockURLProtocol.requestHandler = { request in
            if request.httpMethod == "GET" { return (200, historyBody) }
            return (204, Data())
        }
        await viewModel.loadHistory()

        let serverErrorBody = errorBody(status: 500, message: "Something went wrong")
        MockURLProtocol.requestHandler = { _ in (500, serverErrorBody) }

        await viewModel.clearAll()

        XCTAssertEqual(viewModel.entries.count, 2, "Entries should remain when clearing fails")
        XCTAssertEqual(viewModel.errorMessage, "Something went wrong")
        XCTAssertFalse(viewModel.isClearing)
    }
}
