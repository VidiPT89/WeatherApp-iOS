import SwiftUI
import WidgetKit

/// Home-screen widget for the user's first favorite beach (or, without one, the beach nearest
/// the last known position): next tide, swell and wind, and today's surf verdict.
struct CoastWidget: Widget {
    static let kind = "CoastWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: CoastWidgetProvider()) { entry in
            CoastWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Costa")
        .description("A próxima maré e o mar na tua praia favorita.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct CoastWidgetEntry: TimelineEntry {
    let date: Date
    let reading: CoastWidgetReading?
}

/// What the widget shows at one moment, worked out from a single outlook fetch.
struct CoastWidgetReading {
    let spotName: String
    let swellMeters: Double?
    let periodSeconds: Double?
    let windKmh: Double?
    let windExposure: String?
    let surfScore: Int?
    let nextTide: (isHigh: Bool, time: Date)?
    let followingTide: (isHigh: Bool, time: Date)?
}

struct CoastWidgetProvider: TimelineProvider {
    private static let entryCount = 6

    func placeholder(in context: Context) -> CoastWidgetEntry {
        CoastWidgetEntry(date: .now, reading: Self.sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (CoastWidgetEntry) -> Void) {
        completion(CoastWidgetEntry(date: .now, reading: Self.sample))
    }

    /// One fetch, then an entry per hour for the next few hours, so the "next tide" and the
    /// current swell move on without another network call.
    func getTimeline(in context: Context, completion: @escaping (Timeline<CoastWidgetEntry>) -> Void) {
        nonisolated(unsafe) let completion = completion
        Task {
            let outlook = await CoastWidgetFetcher.fetchOutlook()
            let now = Date()
            let entries = (0..<Self.entryCount).map { offset -> CoastWidgetEntry in
                let date = now.addingTimeInterval(TimeInterval(offset * 3600))
                return CoastWidgetEntry(date: date, reading: outlook?.reading(at: date))
            }
            let retry = outlook == nil ? now.addingTimeInterval(30 * 60) : now.addingTimeInterval(TimeInterval(Self.entryCount * 3600))
            completion(Timeline(entries: entries, policy: .after(retry)))
        }
    }

    static let sample = CoastWidgetReading(
        spotName: "Guincho", swellMeters: 1.5, periodSeconds: 12, windKmh: 12, windExposure: "offshore",
        surfScore: 9, nextTide: (true, .now.addingTimeInterval(2 * 3600)),
        followingTide: (false, .now.addingTimeInterval(8 * 3600)))
}

/// Standalone fetch of `/api/v1/coast/*` for the extension, in the same spirit as
/// `WidgetWeatherFetcher`: its own tiny Decodables, no auth, `nil` on any failure.
enum CoastWidgetFetcher {
    private static var baseURL: URL? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String else { return nil }
        return URL(string: value)
    }

    static func fetchOutlook() async -> RawCoastOutlook? {
        guard let baseURL, let spotId = await resolveSpotId(baseURL: baseURL) else { return nil }
        var components = URLComponents(url: baseURL.appendingPathComponent("api/v1/coast/outlook"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "spot", value: spotId)]
        return await get(components?.url)
    }

    /// The first favorite; otherwise the spot nearest the position the app last saw.
    private static func resolveSpotId(baseURL: URL) async -> String? {
        if let favorite = WeatherWidgetStore.loadFavoriteSpotId() {
            return favorite
        }
        guard let coordinate = WeatherWidgetStore.loadLastKnownCoordinate() else { return nil }
        var components = URLComponents(url: baseURL.appendingPathComponent("api/v1/coast/spots"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "lat", value: String(coordinate.latitude)),
            URLQueryItem(name: "lon", value: String(coordinate.longitude)),
        ]
        let spots: [RawSpot]? = await get(components?.url)
        return spots?.first?.id
    }

    private static func get<T: Decodable>(_ url: URL?) async -> T? {
        guard let url,
              let (data, response) = try? await URLSession.shared.data(from: url),
              let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode)
        else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

private struct RawSpot: Decodable {
    let id: String
}

struct RawCoastOutlook: Decodable {
    struct Spot: Decodable { let name: String }
    struct Hour: Decodable {
        let time: String
        let waveHeightMeters: Double?
        let swellHeightMeters: Double?
        let swellPeriodSeconds: Double?
        let wavePeriodSeconds: Double?
        let windSpeed: Double?
        let windExposure: String?
        let surfScore: Int?
    }
    struct Tide: Decodable {
        let type: String
        let time: String
    }

    let spot: Spot
    let utcOffsetSeconds: Int
    let hours: [Hour]
    let tideEvents: [Tide]

    /// Times in the outlook are the spot's wall-clock, so `instant` is moved onto that clock first.
    func reading(at instant: Date) -> CoastWidgetReading {
        let now = BackendDateFormatters.cityWallClock(of: instant, utcOffsetSeconds: utcOffsetSeconds)
        let hour = hours.last { (BackendDateFormatters.parseLocalDateTime($0.time) ?? .distantFuture) <= now }
            ?? hours.first
        let upcoming = tideEvents.compactMap { tide -> (isHigh: Bool, time: Date)? in
            guard let time = BackendDateFormatters.parseLocalDateTime(tide.time), time > now else { return nil }
            return (tide.type == "high", time)
        }
        return CoastWidgetReading(
            spotName: spot.name,
            swellMeters: hour?.swellHeightMeters ?? hour?.waveHeightMeters,
            periodSeconds: hour?.swellPeriodSeconds ?? hour?.wavePeriodSeconds,
            windKmh: hour?.windSpeed,
            windExposure: hour?.windExposure,
            surfScore: hour?.surfScore,
            nextTide: upcoming.first,
            followingTide: upcoming.dropFirst().first)
    }
}

struct CoastWidgetEntryView: View {
    let entry: CoastWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let reading = entry.reading {
                if family == .systemMedium {
                    medium(reading)
                } else {
                    small(reading)
                }
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "water.waves")
                        .font(.title2)
                    Text("Abre a app e escolhe uma praia favorita")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            LinearGradient(colors: [Color(red: 0.05, green: 0.36, blue: 0.62), Color(red: 0.0, green: 0.6, blue: 0.68)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private func small(_ reading: CoastWidgetReading) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: reading.spotName)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Spacer(minLength: 0)
            if let tide = reading.nextTide {
                tideLabel(tide)
                    .font(.caption)
                    .opacity(0.9)
                Text(tide.time, format: .dateTime.hour().minute())
                    .font(.system(size: 28, weight: .bold, design: .rounded))
            }
            swellLine(reading)
                .font(.caption2)
                .opacity(0.9)
        }
    }

    private func medium(_ reading: CoastWidgetReading) -> some View {
        HStack(alignment: .top, spacing: 16) {
            small(reading)
            VStack(alignment: .leading, spacing: 8) {
                if let tide = reading.followingTide {
                    VStack(alignment: .leading, spacing: 0) {
                        tideLabel(tide).font(.caption).opacity(0.9)
                        Text(tide.time, format: .dateTime.hour().minute()).font(.headline)
                    }
                }
                if let wind = reading.windKmh {
                    HStack(spacing: 4) {
                        Image(systemName: "wind")
                        Text(verbatim: "\(Int(wind.rounded())) km/h")
                        if reading.windExposure == "offshore" {
                            Text("offshore")
                        } else if reading.windExposure == "onshore" {
                            Text("onshore")
                        }
                    }
                    .font(.caption)
                }
                if let score = reading.surfScore {
                    HStack(spacing: 4) {
                        Image(systemName: "figure.surfing")
                        Text(verbatim: "\(score)/10")
                    }
                    .font(.caption.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func tideLabel(_ tide: (isHigh: Bool, time: Date)) -> Text {
        tide.isHigh ? Text("Maré alta") : Text("Maré baixa")
    }

    private func swellLine(_ reading: CoastWidgetReading) -> Text {
        guard let swell = reading.swellMeters else { return Text(verbatim: "") }
        let height = swell.formatted(.number.precision(.fractionLength(1))) + " m"
        guard let period = reading.periodSeconds else { return Text(verbatim: height) }
        return Text(verbatim: "\(height) · \(Int(period.rounded())) s")
    }
}
