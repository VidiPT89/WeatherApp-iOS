import Foundation

/// Small `Codable` snapshot of "the last weather the Dashboard successfully
/// loaded", written by the main app and read by the `WeatherWidget`
/// extension. Deliberately tiny -- sized for `UserDefaults` in an App Group,
/// not a database -- since the widget never fetches independently; it only
/// ever mirrors what the app itself last saw. `description` is kept as the
/// raw backend string (not an icon name) so the widget can run it through
/// the same `WeatherConditionStyle` mapping the main app uses, rather than
/// duplicating that logic.
struct WeatherWidgetSnapshot: Codable, Equatable {
    let city: String
    let country: String
    let temperature: Double
    let feelsLike: Double
    let humidity: Int
    let windSpeed: Double
    let description: String
    let temperatureSymbol: String
    let windSpeedSymbol: String
    let lastUpdated: Date
    /// Whether `lastUpdated` falls outside today's sunrise/sunset -- same signal
    /// `WeatherCardView` uses so the widget can show the same night gradient/icon as the app,
    /// instead of always rendering as if it were day. Decoded as `false` for any snapshot
    /// persisted before this field existed, matching `WeatherConditionStyle`'s own default.
    let isNight: Bool

    init(
        city: String, country: String, temperature: Double, feelsLike: Double, humidity: Int,
        windSpeed: Double, description: String, temperatureSymbol: String, windSpeedSymbol: String,
        lastUpdated: Date, isNight: Bool
    ) {
        self.city = city
        self.country = country
        self.temperature = temperature
        self.feelsLike = feelsLike
        self.humidity = humidity
        self.windSpeed = windSpeed
        self.description = description
        self.temperatureSymbol = temperatureSymbol
        self.windSpeedSymbol = windSpeedSymbol
        self.lastUpdated = lastUpdated
        self.isNight = isNight
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        city = try container.decode(String.self, forKey: .city)
        country = try container.decode(String.self, forKey: .country)
        temperature = try container.decode(Double.self, forKey: .temperature)
        feelsLike = try container.decode(Double.self, forKey: .feelsLike)
        humidity = try container.decode(Int.self, forKey: .humidity)
        windSpeed = try container.decode(Double.self, forKey: .windSpeed)
        description = try container.decode(String.self, forKey: .description)
        temperatureSymbol = try container.decode(String.self, forKey: .temperatureSymbol)
        windSpeedSymbol = try container.decode(String.self, forKey: .windSpeedSymbol)
        lastUpdated = try container.decode(Date.self, forKey: .lastUpdated)
        isNight = try container.decodeIfPresent(Bool.self, forKey: .isNight) ?? false
    }
}

/// Reads/writes `WeatherWidgetSnapshot` to the App Group container shared
/// between the main app and the widget extension. `UserDefaults(suiteName:)`
/// is simplest and plenty for a single small snapshot -- no need for a file
/// or a shared database.
enum WeatherWidgetStore {
    /// Must match the App Group entitlement on both the main app and
    /// `WeatherWidgetExtension` targets (see their `.entitlements` files).
    static let appGroupID = "group.dev.ividi.weatherapp"

    private static let snapshotKey = "weatherWidgetSnapshot.v1"

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    /// Called by the main app after every successful Dashboard weather
    /// fetch. The caller is responsible for also calling
    /// `WidgetCenter.shared.reloadAllTimelines()` afterward -- kept out of
    /// this type so `Shared/` (compiled into the widget extension too)
    /// doesn't need to import WidgetKit.
    static func save(_ snapshot: WeatherWidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        sharedDefaults?.set(data, forKey: snapshotKey)
    }

    /// `nil` when the app has never successfully loaded weather (fresh
    /// install, or the app group isn't available for some reason) -- the
    /// widget must render a graceful placeholder for that case, not crash.
    static func load() -> WeatherWidgetSnapshot? {
        guard let data = sharedDefaults?.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(WeatherWidgetSnapshot.self, from: data)
    }
}
