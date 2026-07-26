import SwiftUI
import Observation

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
            await loadWeather(for: weatherResult.city)
        } catch {
            // Permission denied or lookup failed -- the manual-search empty state stays in place.
        }
    }

    /// Loads the user's saved unit preference. Call once after login/session restore.
    func loadInitialPreferences() async {
        guard let preferences = try? await apiClient.fetchPreferences() else { return }
        units = preferences.units
    }

    func loadWeather(for city: String) async {
        let trimmedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCity.isEmpty else { return }

        isLoading = true
        errorMessage = nil

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
            await loadWeather(for: city)
        }

        Task { try? await apiClient.updatePreferences(units: newUnits) }
    }
}
