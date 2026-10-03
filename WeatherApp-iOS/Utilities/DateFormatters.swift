import Foundation

/// Centralized date formatters/parsers for the shapes the backend sends.
///
/// The backend mixes two date representations in the same payloads:
/// - Instants (`observedAt`, `searchedAt`, `createdAt`, JWT-adjacent fields) are
///   full ISO-8601 strings with an offset/`Z`, e.g. `2024-01-01T12:00:00Z`.
/// - The forecast's `hourly[].time` is a *local* datetime with **no** timezone
///   offset, e.g. `2024-01-01T00:00:00`. Decoding that with `.iso8601` throws,
///   since `.iso8601` requires an offset. It must be parsed as a plain
///   local date via `parseLocalDateTime` instead.
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

    /// Zone-less forecast times (`hourly[].time`, `daily[].sunrise`, ...) are the city's own
    /// wall-clock, e.g. `2024-01-01T07:45:00`. They're returned as the same wall-clock in the
    /// device's calendar, so a view formats them back to exactly those numbers and can lay them
    /// next to `Date.now`. Parsing happens strictly in UTC first, so a time the device's zone
    /// skips (a DST gap) still decodes instead of failing the whole forecast.
    static func parseLocalDateTime(_ string: String) -> Date? {
        localDateTime.date(from: string).map(deviceWallClock(fromUTC:))
    }

    /// Zone-less forecast date (`daily[].date`, e.g. `2024-01-01`), as midnight in the device's calendar.
    static func parseLocalDate(_ string: String) -> Date? {
        localDate.date(from: string).map(deviceWallClock(fromUTC:))
    }

    /// The city's wall-clock at `instant`, in the same device-calendar frame [parseLocalDateTime]
    /// produces -- so a real instant (`observedAt`, `Date.now`) can be compared with sunrise,
    /// sunset or an hourly slot even when the city is in another time zone. Without an offset
    /// (an older backend) the device's own zone is the best remaining guess.
    static func cityWallClock(of instant: Date, utcOffsetSeconds: Int?) -> Date {
        guard let utcOffsetSeconds, let cityZone = TimeZone(secondsFromGMT: utcOffsetSeconds) else { return instant }
        var cityCalendar = Calendar(identifier: .gregorian)
        cityCalendar.timeZone = cityZone
        let components = cityCalendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: instant)
        return Calendar.current.date(from: components) ?? instant
    }

    private static func deviceWallClock(fromUTC date: Date) -> Date {
        let components = utcCalendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        return Calendar.current.date(from: components) ?? date
    }

    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private static let localDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static let localDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
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
