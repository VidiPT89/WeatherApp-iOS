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
    /// Set when the forecast fetch fails while current weather still succeeds.
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
    private var loadGeneration = 0

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
        guard !hasSearchedOnce, !isLocating else { return }
        let generation = loadGeneration

        isLocating = true
        locationErrorMessage = nil
        defer { isLocating = false }

        do {
            let coordinate = try await locationService.requestCurrentLocation()
            guard generation == loadGeneration, !Task.isCancelled else { return }
            WeatherWidgetStore.saveLastKnownCoordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let weatherResult = try await fetchWeatherNearbyWithRetry(
                latitude: coordinate.latitude, longitude: coordinate.longitude)
            guard generation == loadGeneration, !Task.isCancelled else { return }
            let city = weatherResult.country.isEmpty ? weatherResult.city : "\(weatherResult.city), \(weatherResult.country)"
            await loadWeather(for: city, isFromNearbyLocation: true, nearbyWeather: weatherResult)
        } catch is LocationError {
            guard generation == loadGeneration, !Task.isCancelled else { return }
            locationErrorMessage = LocalizedStrings.string("Não foi possível obter a tua localização. Procura uma cidade manualmente.", locale: AppLocale.current.locale)
        } catch {
            guard generation == loadGeneration, !Task.isCancelled else { return }
            locationErrorMessage = LocalizedStrings.string("Não foi possível obter o tempo para a tua localização. Procura uma cidade manualmente.", locale: AppLocale.current.locale)
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
            try Task.checkCancellation()
            return try await apiClient.fetchWeatherNearby(latitude: latitude, longitude: longitude, units: units)
        }
    }

    /// Loads the user's saved unit preference. Call once after login/session restore.
    func loadInitialPreferences() async {
        let generation = loadGeneration
        let initialUnits = units
        guard let preferences = try? await apiClient.fetchPreferences(),
              generation == loadGeneration, units == initialUnits, !Task.isCancelled else { return }
        units = preferences.units
    }

    /// - Parameter isFromNearbyLocation: `true` only for the GPS-detected city
    ///   (`loadNearbyWeatherIfAvailable`) — this gates whether the home-screen
    ///   widget gets updated. The widget is meant to answer "what's the
    ///   weather where I am", not "what was the last city I looked up", so a
    ///   manual search (the default, `false`) must never overwrite it.
    func loadWeather(for city: String, isFromNearbyLocation: Bool = false, nearbyWeather: WeatherResponse? = nil) async {
        let trimmedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCity.isEmpty else { return }

        loadGeneration += 1
        let generation = loadGeneration
        let requestedUnits = units
        defer {
            if generation == loadGeneration { isLoading = false }
        }
        lastLoadedCity = trimmedCity
        isLoading = true
        isLocating = false
        weather = nil
        forecast = nil
        marine = nil
        insights = nil
        errorMessage = nil
        forecastErrorMessage = nil
        lastLoadWasFromNearbyLocation = isFromNearbyLocation

        do {
            async let weatherTask: WeatherResponse = {
                if let nearbyWeather { return nearbyWeather }
                return try await self.apiClient.fetchWeather(city: trimmedCity, units: requestedUnits)
            }()
            // Forecast, sea conditions, and insights are secondary, best-effort additions to the
            // dashboard: a hiccup on any of them shouldn't blank
            // out the current-conditions card the user actually asked for. Only the current
            // weather fetch itself can fail the whole load. Forecast's outcome is captured as a
            // (data, errorMessage) pair rather than plain `try?` so the view can explain *why*
            // that section is missing instead of just silently omitting it.
            async let forecastOutcome = Self.fetchForecastOutcome(
                apiClient: apiClient, city: trimmedCity, units: requestedUnits, locale: AppLocale.current.locale)
            async let marineTask: MarineResponse? = try? apiClient.fetchMarine(city: trimmedCity, units: requestedUnits)
            async let insightsTask: WeatherInsightsResponse? = try? apiClient.fetchInsights(city: trimmedCity, units: requestedUnits)

            let weatherResult = try await weatherTask
            guard generation == loadGeneration, !Task.isCancelled else { return }
            weather = weatherResult
            isLoading = false
            let forecastResult = await forecastOutcome
            guard generation == loadGeneration, !Task.isCancelled else { return }
            (forecast, forecastErrorMessage) = forecastResult
            let marineResult = await marineTask
            guard generation == loadGeneration, !Task.isCancelled else { return }
            marine = marineResult
            let insightsResult = await insightsTask
            guard generation == loadGeneration, !Task.isCancelled else { return }
            insights = insightsResult
            if isFromNearbyLocation {
                updateWidgetSnapshot(with: weatherResult)
            }
        } catch let apiError as APIError {
            guard generation == loadGeneration, !Task.isCancelled else { return }
            errorMessage = apiError.errorDescription
        } catch {
            guard generation == loadGeneration, !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
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
        loadGeneration += 1
        units = newUnits
        isLocating = false

        if let city = lastLoadedCity {
            // Preserve whether this city came from GPS auto-detection so a units toggle doesn't
            // accidentally start (or stop) updating the widget.
            await loadWeather(for: city, isFromNearbyLocation: lastLoadWasFromNearbyLocation)
        }

        Task { try? await apiClient.updatePreferences(units: newUnits) }
    }

    /// Every successful nearby-location Dashboard load writes a fresh snapshot to the shared App
    /// Group container and asks WidgetKit to refresh immediately, keeping the widget in sync with
    /// what the app itself just saw. The widget can also fetch on its own (`WidgetWeatherFetcher`)
    /// when this snapshot goes stale and the app hasn't been opened -- see `WeatherWidgetProvider`.
    private func updateWidgetSnapshot(with weather: WeatherResponse) {
        // Same day/night check WeatherCardView uses -- without it the widget always rendered as
        // if it were day (bright gradient + sun icon), even overnight.
        let isNight = forecast?.isNight(at: weather.observedAt) ?? false
        WeatherWidgetStore.save(WeatherWidgetSnapshot(weather: weather, isNight: isNight))
        WidgetCenter.shared.reloadAllTimelines()
    }
}
