import SwiftUI
import Observation
import WidgetKit

enum ForecastRange: String, CaseIterable, Identifiable {
    case hourly
    case daily

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .hourly: return "Horária"
        case .daily: return "Diária"
        }
    }
}

/// Backs the main Dashboard screen: current weather + forecast + sea
/// conditions for a searched/selected city, the unit toggle, and the
/// loading/error/empty states.
@MainActor
@Observable
final class DashboardViewModel {
    private(set) var weather: WeatherResponse?
    private(set) var forecast: ForecastResponse?
    /// Sea conditions for the loaded city. `nil` both while loading/on error
    /// AND when the marine endpoint simply has no data for an inland city —
    /// `marine?.hasData` distinguishes "no card" from "empty card" in the view.
    private(set) var marine: MarineResponse?
    /// Derived insights (moon phase, UV risk, activity score, fishing
    /// conditions) — best-effort like `marine`, `nil` on hiccup or while loading.
    private(set) var insights: WeatherInsightsResponse?
    private(set) var isLoading = false
    /// True only while attempting the initial auto-location lookup, distinct
    /// from `isLoading` so the empty state can show a "finding you" message
    /// instead of the full skeleton for that brief step.
    private(set) var isLocating = false
    private(set) var errorMessage: String?
    private(set) var lastLoadedCity: String?
    /// Whether `lastLoadedCity` came from GPS auto-detection rather than a manual search —
    /// see `loadWeather(for:isFromNearbyLocation:)`.
    private var lastLoadWasFromNearbyLocation = false

    var units: Units = .metric
    var forecastRange: ForecastRange = .hourly

    /// Whether anything has been searched yet — drives the empty state.
    var hasSearchedOnce: Bool { lastLoadedCity != nil }

    private let apiClient: APIClient
    private let locationService: LocationService

    init(apiClient: APIClient = .shared, locationService: LocationService = LocationService()) {
        self.apiClient = apiClient
        self.locationService = locationService
    }

    /// Auto-detects the user's location and loads its weather. Fails silently
    /// (leaving the normal manual-search empty state) on denied permission or
    /// any lookup error — this is a convenience, not a required flow.
    func loadNearbyWeatherIfAvailable() async {
        guard !hasSearchedOnce else { return }

        isLocating = true
        defer { isLocating = false }

        do {
            let coordinate = try await locationService.requestCurrentLocation()
            let weatherResult = try await apiClient.fetchWeatherNearby(
                latitude: coordinate.latitude, longitude: coordinate.longitude, units: units)
            await loadWeather(for: weatherResult.city, isFromNearbyLocation: true)
        } catch {
            // Permission denied or lookup failed -- the manual-search empty state stays in place.
        }
    }

    /// Loads the user's saved unit preference. Call once after login/session restore.
    func loadInitialPreferences() async {
        guard let preferences = try? await apiClient.fetchPreferences() else { return }
        units = preferences.units
    }

    /// - Parameter isFromNearbyLocation: `true` only for the GPS-detected city
    ///   (`loadNearbyWeatherIfAvailable`) — this gates whether the home-screen
    ///   widget gets updated. The widget is meant to answer "what's the
    ///   weather where I am", not "what was the last city I looked up", so a
    ///   manual search (the default, `false`) must never overwrite it.
    func loadWeather(for city: String, isFromNearbyLocation: Bool = false) async {
        let trimmedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCity.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        lastLoadWasFromNearbyLocation = isFromNearbyLocation

        do {
            async let weatherTask = apiClient.fetchWeather(city: trimmedCity, units: units)
            async let forecastTask = apiClient.fetchForecast(city: trimmedCity, units: units)
            // Sea conditions are a secondary, best-effort addition to the
            // dashboard: a marine-endpoint hiccup shouldn't blank out the
            // weather card and forecast the user actually searched for.
            async let marineTask: MarineResponse? = try? apiClient.fetchMarine(city: trimmedCity, units: units)
            async let insightsTask: WeatherInsightsResponse? = try? apiClient.fetchInsights(city: trimmedCity, units: units)

            let (weatherResult, forecastResult) = try await (weatherTask, forecastTask)
            weather = weatherResult
            forecast = forecastResult
            lastLoadedCity = trimmedCity
            marine = await marineTask
            insights = await insightsTask
            if isFromNearbyLocation {
                updateWidgetSnapshot(with: weatherResult)
            }
        } catch let apiError as APIError {
            errorMessage = apiError.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Switches units and re-fetches for the currently loaded city, then
    /// fire-and-forgets a save of the new preference.
    func changeUnits(to newUnits: Units) async {
        guard newUnits != units else { return }
        units = newUnits

        if let city = lastLoadedCity {
            // Preserve whether this city came from GPS auto-detection so a units toggle doesn't
            // accidentally start (or stop) updating the widget.
            await loadWeather(for: city, isFromNearbyLocation: lastLoadWasFromNearbyLocation)
        }

        Task { try? await apiClient.updatePreferences(units: newUnits) }
    }

    /// The widget shows the last weather the app itself fetched -- it never
    /// fetches independently. Every successful Dashboard load writes a fresh
    /// snapshot to the shared App Group container and asks WidgetKit to
    /// refresh immediately, rather than the widget polling on its own timer.
    private func updateWidgetSnapshot(with weather: WeatherResponse) {
        let snapshot = WeatherWidgetSnapshot(
            city: weather.city,
            country: weather.country,
            temperature: weather.temperature,
            feelsLike: weather.feelsLike,
            humidity: weather.humidity,
            windSpeed: weather.windSpeed,
            description: weather.description,
            temperatureSymbol: weather.units.temperatureSymbol,
            windSpeedSymbol: weather.units.windSpeedSymbol,
            lastUpdated: weather.observedAt
        )
        WeatherWidgetStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
