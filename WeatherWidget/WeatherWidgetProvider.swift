import WidgetKit

/// A single timeline entry: either the app's last-known weather snapshot, or
/// `nil` when the app has never successfully loaded weather yet (fresh
/// install) -- the view renders a placeholder for that case.
struct WeatherWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WeatherWidgetSnapshot?
}

/// Reads the shared App Group snapshot the main app wrote after its last
/// successful Dashboard fetch. By explicit design this widget never fetches
/// weather on its own -- no network access, no background refresh -- it's a
/// passive mirror of whatever the app last saw. Updates only happen when the
/// app calls `WidgetCenter.shared.reloadAllTimelines()`, so the timeline
/// itself uses a `.never` reload policy rather than trying to poll.
struct WeatherWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeatherWidgetEntry {
        WeatherWidgetEntry(date: .now, snapshot: WeatherWidgetProvider.placeholderSnapshot)
    }

    func getSnapshot(in context: Context, completion: @escaping (WeatherWidgetEntry) -> Void) {
        if context.isPreview {
            completion(WeatherWidgetEntry(date: .now, snapshot: WeatherWidgetProvider.placeholderSnapshot))
        } else {
            completion(WeatherWidgetEntry(date: .now, snapshot: WeatherWidgetStore.load()))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeatherWidgetEntry>) -> Void) {
        let entry = WeatherWidgetEntry(date: .now, snapshot: WeatherWidgetStore.load())
        // App-driven updates only: the main app calls reloadAllTimelines()
        // itself right after writing a fresh snapshot, so there's nothing
        // for a time-based refresh to accomplish here.
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }

    /// Sample data for gallery/preview contexts (widget picker, Xcode
    /// previews) -- never shown as real data on a device.
    static let placeholderSnapshot = WeatherWidgetSnapshot(
        city: "Lisboa",
        country: "Portugal",
        temperature: 21,
        feelsLike: 20,
        humidity: 58,
        windSpeed: 14,
        description: "clear sky",
        temperatureSymbol: "°C",
        windSpeedSymbol: "km/h",
        lastUpdated: .now
    )
}
