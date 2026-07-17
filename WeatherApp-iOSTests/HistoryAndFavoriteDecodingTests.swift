import XCTest
@testable import WeatherApp_iOS

final class HistoryAndFavoriteDecodingTests: XCTestCase {
    func test_decodesHistoryEntryList_sortableByInstant() throws {
        let json = """
        [
          {"city": "Lisboa", "units": "metric", "searchedAt": "2024-01-01T10:00:00Z"},
          {"city": "Porto", "units": "imperial", "searchedAt": "2024-01-02T10:00:00Z"}
        ]
        """.data(using: .utf8)!

        let entries = try JSONDecoder().decode([HistoryEntry].self, from: json)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].units, .metric)
        XCTAssertTrue(entries[1].searchedAt > entries[0].searchedAt)
    }

    func test_decodesFavoriteCity() throws {
        let json = """
        {"city": "Faro", "createdAt": "2024-01-01T10:00:00Z"}
        """.data(using: .utf8)!

        let favorite = try JSONDecoder().decode(FavoriteCity.self, from: json)
        XCTAssertEqual(favorite.city, "Faro")
        XCTAssertEqual(favorite.id, "Faro")
    }

    func test_decodesGeocodingResponse() throws {
        let json = """
        {"query": "lis", "results": [{"name": "Lisboa", "country": "Portugal", "latitude": 38.72, "longitude": -9.13}]}
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(GeocodingResponse.self, from: json)
        XCTAssertEqual(response.results.first?.name, "Lisboa")
    }
}
