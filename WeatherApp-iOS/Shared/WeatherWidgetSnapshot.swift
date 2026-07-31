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
    let description: String
    let temperatureSymbol: String
    let lastUpdated: Date
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
