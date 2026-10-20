import Foundation

/// A beach from `GET /api/v1/coast/spots`. `facingDegrees` is the direction the beach looks
/// out to sea (`nil` for an arbitrary point); `distanceKm` is only set when the list was
/// requested with the user's position.
struct CoastSpot: Decodable, Equatable, Identifiable, Hashable {
    let id: String
    let name: String
    let area: String?
    let latitude: Double
    let longitude: Double
    let facingDegrees: Int?
    let distanceKm: Double?
}

/// The spot as echoed back inside an outlook; `id` is `nil` for an arbitrary point.
struct CoastOutlookSpot: Decodable, Equatable {
    let id: String?
    let name: String
    let area: String?
    let latitude: Double
    let longitude: Double
    let facingDegrees: Int?
}

enum CoastActivity: String, CaseIterable, Identifiable {
    case surf, fishing, beach

    var id: String { rawValue }
}

/// The best few daylight hours of a day for one activity. `end` is exclusive.
struct ActivityWindow: Decodable, Equatable {
    let start: Date
    let end: Date
    let score: Int
    let reasons: [String]

    enum CodingKeys: String, CodingKey { case start, end, score, reasons }

    init(start: Date, end: Date, score: Int, reasons: [String]) {
        self.start = start
        self.end = end
        self.score = score
        self.reasons = reasons
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        start = try container.decodeLocalDateTime(forKey: .start)
        end = try container.decodeLocalDateTime(forKey: .end)
        score = try container.decode(Int.self, forKey: .score)
        reasons = try container.decode([String].self, forKey: .reasons)
    }
}

/// One hour of `GET /api/v1/coast/outlook`. Waves are always meters; wind and temperatures
/// follow the response's `units`. `windExposure` is "offshore", "cross-shore" or "onshore"
/// (`nil` without a beach orientation).
struct CoastHour: Decodable, Equatable, Identifiable {
    let time: Date
    let waveHeightMeters: Double?
    let wavePeriodSeconds: Double?
    let waveDirectionDegrees: Double?
    let swellHeightMeters: Double?
    let swellPeriodSeconds: Double?
    let swellDirectionDegrees: Double?
    let windSpeed: Double?
    let windGusts: Double?
    let windDirectionDegrees: Double?
    let windExposure: String?
    let seaLevelMeters: Double?
    let waterTemperature: Double?
    let airTemperature: Double?
    let precipitationProbability: Int?
    let surfScore: Int?
    let fishingScore: Int?
    let beachScore: Int?

    var id: Date { time }

    func score(for activity: CoastActivity) -> Int? {
        switch activity {
        case .surf: return surfScore
        case .fishing: return fishingScore
        case .beach: return beachScore
        }
    }

    enum CodingKeys: String, CodingKey {
        case time, waveHeightMeters, wavePeriodSeconds, waveDirectionDegrees
        case swellHeightMeters, swellPeriodSeconds, swellDirectionDegrees
        case windSpeed, windGusts, windDirectionDegrees, windExposure, seaLevelMeters
        case waterTemperature, airTemperature, precipitationProbability
        case surfScore, fishingScore, beachScore
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        time = try c.decodeLocalDateTime(forKey: .time)
        waveHeightMeters = try c.decodeIfPresent(Double.self, forKey: .waveHeightMeters)
        wavePeriodSeconds = try c.decodeIfPresent(Double.self, forKey: .wavePeriodSeconds)
        waveDirectionDegrees = try c.decodeIfPresent(Double.self, forKey: .waveDirectionDegrees)
        swellHeightMeters = try c.decodeIfPresent(Double.self, forKey: .swellHeightMeters)
        swellPeriodSeconds = try c.decodeIfPresent(Double.self, forKey: .swellPeriodSeconds)
        swellDirectionDegrees = try c.decodeIfPresent(Double.self, forKey: .swellDirectionDegrees)
        windSpeed = try c.decodeIfPresent(Double.self, forKey: .windSpeed)
        windGusts = try c.decodeIfPresent(Double.self, forKey: .windGusts)
        windDirectionDegrees = try c.decodeIfPresent(Double.self, forKey: .windDirectionDegrees)
        windExposure = try c.decodeIfPresent(String.self, forKey: .windExposure)
        seaLevelMeters = try c.decodeIfPresent(Double.self, forKey: .seaLevelMeters)
        waterTemperature = try c.decodeIfPresent(Double.self, forKey: .waterTemperature)
        airTemperature = try c.decodeIfPresent(Double.self, forKey: .airTemperature)
        precipitationProbability = try c.decodeIfPresent(Int.self, forKey: .precipitationProbability)
        surfScore = try c.decodeIfPresent(Int.self, forKey: .surfScore)
        fishingScore = try c.decodeIfPresent(Int.self, forKey: .fishingScore)
        beachScore = try c.decodeIfPresent(Int.self, forKey: .beachScore)
    }
}

struct CoastDay: Decodable, Equatable, Identifiable {
    let date: Date
    let sunrise: Date
    let sunset: Date
    let surf: ActivityWindow?
    let fishing: ActivityWindow?
    let beach: ActivityWindow?

    var id: Date { date }

    func window(for activity: CoastActivity) -> ActivityWindow? {
        switch activity {
        case .surf: return surf
        case .fishing: return fishing
        case .beach: return beach
        }
    }

    enum CodingKeys: String, CodingKey { case date, sunrise, sunset, surf, fishing, beach }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let rawDate = try c.decode(String.self, forKey: .date)
        guard let parsedDate = BackendDateFormatters.parseLocalDate(rawDate) else {
            throw DateDecodingError.invalidLocalDate(rawDate)
        }
        date = parsedDate
        sunrise = try c.decodeLocalDateTime(forKey: .sunrise)
        sunset = try c.decodeLocalDateTime(forKey: .sunset)
        surf = try c.decodeIfPresent(ActivityWindow.self, forKey: .surf)
        fishing = try c.decodeIfPresent(ActivityWindow.self, forKey: .fishing)
        beach = try c.decodeIfPresent(ActivityWindow.self, forKey: .beach)
    }
}

struct CoastOutlookResponse: Decodable, Equatable {
    let spot: CoastOutlookSpot
    let units: Units
    let provider: String
    let fromCache: Bool
    let utcOffsetSeconds: Int
    let hours: [CoastHour]
    let tideEvents: [TideEvent]
    let days: [CoastDay]

    /// The spot's own wall-clock now, in the same frame as the decoded `hours` (see
    /// `BackendDateFormatters.cityWallClock`).
    func spotNow(_ instant: Date = .now) -> Date {
        BackendDateFormatters.cityWallClock(of: instant, utcOffsetSeconds: utcOffsetSeconds)
    }

    /// The hour slot containing `now` (spot time), or the first one if the outlook is stale.
    func currentHour(now: Date) -> CoastHour? {
        hours.last(where: { $0.time <= now }) ?? hours.first
    }

    func hours(on day: Date) -> [CoastHour] {
        hours.filter { Calendar.current.isDate($0.time, inSameDayAs: day) }
    }

    /// Tide turns on `day`, as dates in the same wall-clock frame as `hours`.
    func tides(on day: Date) -> [(isHigh: Bool, time: Date)] {
        tideEvents.compactMap { event in
            guard let time = BackendDateFormatters.parseLocalDateTime(event.time),
                  Calendar.current.isDate(time, inSameDayAs: day) else { return nil }
            return (event.isHigh, time)
        }
    }

    /// The first tide turn after `now`.
    func nextTide(after now: Date) -> (isHigh: Bool, time: Date)? {
        tideEvents.lazy.compactMap { event -> (isHigh: Bool, time: Date)? in
            guard let time = BackendDateFormatters.parseLocalDateTime(event.time), time > now else { return nil }
            return (event.isHigh, time)
        }.first
    }
}

private extension KeyedDecodingContainer {
    func decodeLocalDateTime(forKey key: Key) throws -> Date {
        let raw = try decode(String.self, forKey: key)
        guard let parsed = BackendDateFormatters.parseLocalDateTime(raw) else {
            throw DateDecodingError.invalidLocalDateTime(raw)
        }
        return parsed
    }
}
