import Foundation

/// Named constants shared across view models, replacing magic numbers.
enum AppConstants {
    /// Debounce delay before firing a geocoding autocomplete request.
    static let searchDebounceNanoseconds: UInt64 = 300_000_000 // 300ms

    /// Minimum characters typed before autocomplete queries the backend.
    static let minSearchCharacters = 2

    /// How often the cache-age label recomputes ("há Xs/Xmin/Xh").
    static let cacheAgeTickInterval: TimeInterval = 1

    /// Backend's in-memory weather cache TTL, mirrored here only for display copy.
    static let cacheTTLMinutes = 15

    static let defaultGeocodingLimit = 5
}
