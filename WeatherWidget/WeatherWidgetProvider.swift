import WidgetKit

/// A single timeline entry: either the app's last-known weather snapshot, or
/// `nil` when the app has never successfully loaded weather yet (fresh
/// install) -- the view renders a placeholder for that case.
struct WeatherWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WeatherWidgetSnapshot?
}

/// Reads the shared App Group snapshot the main app wrote after its last successful Dashboard
/// fetch, same as before -- but when that snapshot is missing or older than
/// `freshEnoughInterval`, `getTimeline` now also tries a live fetch of its own
/// (`WidgetWeatherFetcher`) before rendering, so a freshly-placed widget shows real data
/// immediately instead of "no data yet" until the app is opened or the main app's periodic
/// background refresh (`WidgetRefreshScheduler`) happens to run. Still `.never` reload policy --
/// updates are triggered by the main app (`reloadAllTimelines()`) or by this provider itself being
/// re-invoked by the system (widget placement, returning to the home screen, etc.), not by a
/// time-based WidgetKit poll.
struct WeatherWidgetProvider: TimelineProvider {
    /// Below this age, an existing snapshot is shown as-is without a live fetch -- placing/
    /// reopening the widget shouldn't re-hit the network on every single glance at the home
    /// screen when the last read is still reasonably current.
    private static let freshEnoughInterval: TimeInterval = 30 * 60

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
        let stored = WeatherWidgetStore.load()
        if let stored, Date().timeIntervalSince(stored.lastUpdated) < Self.freshEnoughInterval {
            completion(Timeline(entries: [WeatherWidgetEntry(date: .now, snapshot: stored)], policy: .never))
            return
        }

        // `completion` isn't declared `@Sendable` in WidgetKit's `TimelineProvider` protocol, but
        // is safe to call from any thread/context (it's just a callback into WidgetKit's own
        // scheduling) -- same rationale as the `nonisolated(unsafe)` on `BGAppRefreshTask` in
        // `WidgetRefreshScheduler`.
        nonisolated(unsafe) let completion = completion
        Task {
            let fetched = await WidgetWeatherFetcher.fetchNearbySnapshot()
            if let fetched {
                // Keeps the main app's own next read in sync with what the widget just fetched.
                WeatherWidgetStore.save(fetched)
            }
            let entry = WeatherWidgetEntry(date: .now, snapshot: fetched ?? stored)
            completion(Timeline(entries: [entry], policy: .never))
        }
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
        lastUpdated: .now,
        isNight: false
    )
}
