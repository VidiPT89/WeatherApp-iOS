import BackgroundTasks
import CoreLocation
import Foundation
import WidgetKit

/// Keeps the home-screen widget fresh in the background, without the user needing to open the
/// app -- see `WeatherWidgetStore`'s "app-driven only" design note. This periodic background
/// fetch is the one deliberate exception, replaying the same GPS-lookup + snapshot-save path
/// `DashboardViewModel.loadNearbyWeatherIfAvailable` already uses on open, on a schedule instead
/// of "the app happened to be open". Mirrors `WeatherApp-Android`'s `WeatherWidgetRefreshWorker`.
enum WidgetRefreshScheduler {
    static let taskIdentifier = "dev.ividi.weatherapp.widgetRefresh"

    // 3h, matching the Android worker's interval -- a reasonable balance between how fresh a
    // glanceable widget needs to be and battery/network/backend cold-start cost. iOS treats this
    // as a minimum, not a guarantee: the OS decides the actual next run based on usage patterns.
    private static let refreshInterval: TimeInterval = 3 * 60 * 60

    /// Call once at app launch (before the app can be backgrounded), from `WeatherApp_iOSApp`'s
    /// initializer -- `BGTaskScheduler.register` must happen before `applicationDidFinishLaunching`
    /// returns, or the OS refuses to ever run the task.
    static func registerTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            handle(refreshTask)
        }
    }

    /// Queues the next run. Safe to call repeatedly (e.g. every time the app is backgrounded) --
    /// a new request simply replaces any pending one for the same identifier.
    static func scheduleNextRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: refreshInterval)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handle(_ task: BGAppRefreshTask) {
        // Re-arm immediately so one execution (successful or not) doesn't end the periodic chain
        // -- the OS gives no separate "repeat" mechanism for BGAppRefreshTask, each run has to
        // schedule its own successor.
        scheduleNextRefresh()

        // BGAppRefreshTask predates Swift concurrency and isn't Sendable -- safe to hand across
        // the Task boundary here regardless, since nothing else touches it concurrently: only
        // this completion callback and the expiration handler below ever call into it, and BGTask
        // itself is documented as safe to complete from any thread.
        nonisolated(unsafe) let task = task

        let refreshTask = Task {
            await refresh()
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = {
            refreshTask.cancel()
        }
    }

    /// Fails silently on any error -- same "convenience, not required" stance as the app's own
    /// nearby-location lookup (`DashboardViewModel.loadNearbyWeatherIfAvailable`); the next
    /// scheduled run tries again regardless. Deliberately skips ever requesting permission itself
    /// (a background task can't usefully prompt the user) -- only runs if location access was
    /// already granted from a prior foreground use of the app.
    private static func refresh() async {
        let status = CLLocationManager().authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else { return }

        do {
            let location = try await LocationService().requestCurrentLocation()
            let units = try? await APIClient.shared.fetchPreferences().units
            let weather = try await APIClient.shared.fetchWeatherNearby(
                latitude: location.latitude, longitude: location.longitude, units: units)
            WeatherWidgetStore.save(WeatherWidgetSnapshot(weather: weather))
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            // Intentionally ignored -- see doc comment above.
        }
    }
}
