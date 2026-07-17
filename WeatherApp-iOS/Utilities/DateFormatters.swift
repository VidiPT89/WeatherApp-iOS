import Foundation

/// Centralized date formatters/parsers for the shapes the backend sends.
///
/// The backend mixes two date representations in the same payloads:
/// - Instants (`observedAt`, `searchedAt`, `createdAt`, JWT-adjacent fields) are
///   full ISO-8601 strings with an offset/`Z`, e.g. `2024-01-01T12:00:00Z`.
/// - The forecast's `hourly[].time` is a *local* datetime with **no** timezone
///   offset, e.g. `2024-01-01T00:00:00`. Decoding that with `.iso8601` throws,
///   since `.iso8601` requires an offset. It must be parsed as a plain
///   local date via a custom formatter instead.
enum BackendDateFormatters {
    /// Full ISO-8601 instant, e.g. `2024-01-01T12:00:00Z` or with fractional seconds.
    /// `nonisolated(unsafe)`: these formatters are configured once at first access
    /// and only ever read afterward (via `.date(from:)`), so the shared mutable
    /// state the compiler warns about is never actually mutated concurrently.
    nonisolated(unsafe) static let isoInstant: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// Fallback for instants without fractional seconds.
    nonisolated(unsafe) static let isoInstantNoFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func parseInstant(_ string: String) -> Date? {
        isoInstant.date(from: string) ?? isoInstantNoFraction.date(from: string)
    }

    /// Local (zone-less) datetime used by `forecast.hourly[].time`,
    /// e.g. `2024-01-01T00:00:00`.
    nonisolated(unsafe) static let localDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    /// Local (zone-less) date used by `forecast.daily[].date`, e.g. `2024-01-01`.
    nonisolated(unsafe) static let localDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    /// Short display formatter for hourly forecast axis labels, e.g. "14h".
    nonisolated(unsafe) static let hourLabel: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH'h'"
        formatter.locale = Locale(identifier: "pt_PT")
        return formatter
    }()

    /// Short display formatter for daily forecast axis labels, e.g. "seg".
    nonisolated(unsafe) static let weekdayLabel: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        formatter.locale = Locale(identifier: "pt_PT")
        return formatter
    }()

    /// Human display formatter for history/favorites timestamps.
    nonisolated(unsafe) static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "pt_PT")
        formatter.unitsStyle = .full
        return formatter
    }()
}

/// A `Decodable`/`Encodable`-friendly wrapper isn't needed here — models decode
/// these dates manually via `init(from:)` using the formatters above, since a
/// single JSONDecoder-wide `dateDecodingStrategy` can't handle both instant and
/// zone-less local dates in the same response.
enum DateDecodingError: Error, LocalizedError {
    case invalidInstant(String)
    case invalidLocalDateTime(String)
    case invalidLocalDate(String)

    var errorDescription: String? {
        switch self {
        case .invalidInstant(let raw):
            return "Invalid instant date string: \(raw)"
        case .invalidLocalDateTime(let raw):
            return "Invalid local date-time string: \(raw)"
        case .invalidLocalDate(let raw):
            return "Invalid local date string: \(raw)"
        }
    }
}
