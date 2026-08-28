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
    /// Set only when the forecast fetch itself fails (e.g. Open-Meteo's shared-IP quota, which
    /// forecast has no fallback provider for -- see ADR-001) while `weather` still succeeded.
    /// Lets the view show *why* the forecast section is missing instead of just silently omitting
    /// it, matching how `WeatherApp-Android`'s per-section states already behave.
    private(set) var forecastErrorMessage: String?
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
    /// Set only when the auto-location convenience itself fails (GPS timeout/denial or the
    /// nearby-lookup request) -- distinct from `errorMessage`, which is reserved for a failed
    /// manual search, so a failed auto-locate doesn't get mistaken for a bad city search.
    private(set) var locationErrorMessage: String?
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

    /// Auto-detects the user's location and loads its weather. Falls back to the normal
    /// manual-search empty state on denied permission or any lookup error -- this is a
    /// convenience, not a required flow -- but sets `locationErrorMessage` so the empty state
    /// can explain *why* instead of reverting with no feedback (a GPS fix can genuinely fail or
    /// take a long time indoors/with poor signal, and silently going nowhere read as "broken").
    func loadNearbyWeatherIfAvailable() async {
        guard !hasSearchedOnce else { return }

        isLocating = true
        locationErrorMessage = nil
        defer { isLocating = false }

        do {
            let coordinate = try await locationService.requestCurrentLocation()
            let weatherResult = try await fetchWeatherNearbyWithRetry(
                latitude: coordinate.latitude, longitude: coordinate.longitude)
            await loadWeather(for: weatherResult.city, isFromNearbyLocation: true)
        } catch is LocationError {
            locationErrorMessage = "Não foi possível obter a tua localização. Procura uma cidade manualmente."
        } catch {
            locationErrorMessage = "Não foi possível obter o tempo para a tua localização. Procura uma cidade manualmente."
        }
    }

    /// The backend's free-tier host can occasionally take longer to cold-boot than even our
    /// extended 180s request timeout (see `APIClient.defaultSession`), which fails the very first
    /// request after a long idle period. By the time that happens the backend has finished
    /// booting anyway, so one immediate retry succeeds in practice instead of dead-ending the
    /// user into a manual search.
    private func fetchWeatherNearbyWithRetry(latitude: Double, longitude: Double) async throws -> WeatherResponse {
        do {
            return try await apiClient.fetchWeatherNearby(latitude: latitude, longitude: longitude, units: units)
        } catch {
            return try await apiClient.fetchWeatherNearby(latitude: latitude, longitude: longitude, units: units)
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
        forecastErrorMessage = nil
        lastLoadWasFromNearbyLocation = isFromNearbyLocation

        do {
            async let weatherTask = apiClient.fetchWeather(city: trimmedCity, units: units)
            // Forecast, sea conditions, and insights are secondary, best-effort additions to the
            // dashboard: a hiccup on any of them (e.g. Open-Meteo's shared-IP quota on Render,
            // which has no fallback provider for forecast/marine -- see ADR-001) shouldn't blank
            // out the current-conditions card the user actually asked for. Only the current
            // weather fetch itself can fail the whole load. Forecast's outcome is captured as a
            // (data, errorMessage) pair rather than plain `try?` so the view can explain *why*
            // that section is missing instead of just silently omitting it.
            async let forecastOutcome = Self.fetchForecastOutcome(
                apiClient: apiClient, city: trimmedCity, units: units, locale: AppLocale.current.locale)
            async let marineTask: MarineResponse? = try? apiClient.fetchMarine(city: trimmedCity, units: units)
            async let insightsTask: WeatherInsightsResponse? = try? apiClient.fetchInsights(city: trimmedCity, units: units)

            let weatherResult = try await weatherTask
            weather = weatherResult
            lastLoadedCity = trimmedCity
            (forecast, forecastErrorMessage) = await forecastOutcome
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

    private static func fetchForecastOutcome(
        apiClient: APIClient, city: String, units: Units, locale: Locale
    ) async -> (ForecastResponse?, String?) {
        do {
            return (try await apiClient.fetchForecast(city: city, units: units), nil)
        } catch let apiError as APIError {
            return (nil, apiError.localizedDescription(locale: locale))
        } catch {
            return (nil, error.localizedDescription)
        }
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
        // Same day/night check WeatherCardView uses -- without it the widget always rendered as
        // if it were day (bright gradient + sun icon), even overnight.
        let isNight: Bool
        if let today = forecast?.daily.first {
            isNight = weather.observedAt < today.sunrise || weather.observedAt > today.sunset
        } else {
            isNight = false
        }
        WeatherWidgetStore.save(WeatherWidgetSnapshot(weather: weather, isNight: isNight))
        WidgetCenter.shared.reloadAllTimelines()
    }
}
