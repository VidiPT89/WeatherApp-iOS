import Foundation

/// A GPS fix sent alongside a reverse-geocoded city name, so the backend can look the place up
/// by position instead of by a name it may not recognise (e.g. a parish).
struct GeoCoordinate: Equatable, Sendable {
    let latitude: Double
    let longitude: Double
}
