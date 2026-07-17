import Foundation
import Observation

enum ForecastRange: String, CaseIterable, Identifiable {
    case hourly = "Horária"
    case daily = "Diária"

    var id: String { rawValue }
}

/// Backs the main Dashboard screen: current weather + forecast for a
/// searched/selected city, the unit toggle, and the loading/error/empty states.
@MainActor
@Observable
final class DashboardViewModel {
    private(set) var weather: WeatherResponse?
    private(set) var forecast: ForecastResponse?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var lastLoadedCity: String?

    var units: Units = .metric
    var forecastRange: ForecastRange = .hourly

    /// Whether anything has been searched yet — drives the empty state.
    var hasSearchedOnce: Bool { lastLoadedCity != nil }

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
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
            let (weatherResult, forecastResult) = try await (weatherTask, forecastTask)
            weather = weatherResult
            forecast = forecastResult
            lastLoadedCity = trimmedCity
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
