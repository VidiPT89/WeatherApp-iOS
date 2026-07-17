import Foundation

/// One city suggestion within `GET /api/v1/geocoding`.
struct GeocodingResult: Decodable, Equatable, Identifiable {
    let name: String
    let country: String
    let latitude: Double
    let longitude: Double

    var id: String { "\(name)-\(country)-\(latitude)-\(longitude)" }
}

/// `GET /api/v1/geocoding` response.
struct GeocodingResponse: Decodable, Equatable {
    let query: String
    let results: [GeocodingResult]
}
