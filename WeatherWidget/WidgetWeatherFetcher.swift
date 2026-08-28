import CoreLocation
import Foundation

/// Lets the widget extension fetch current weather for the device's location entirely on its own
/// -- no main app launch required -- so a freshly-placed widget (or one that's gone stale) shows
/// real data immediately instead of waiting on the main app's periodic background refresh
/// (`WidgetRefreshScheduler`) or the user opening the app. Kept deliberately standalone (its own
/// tiny `RawWeatherResponse`, not the main app's `APIClient`/`WeatherResponse`) so the extension
/// doesn't need to link Google/MSAL sign-in or anything auth-related -- `/api/v1/weather/nearby`
/// already works anonymously.
enum WidgetWeatherFetcher {
    private static var baseURL: URL? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String else { return nil }
        return URL(string: value)
    }

    /// Best-effort: `nil` on any failure (permission not yet granted from the main app, no GPS
    /// fix, network/decoding error) -- same "convenience, not required" stance as the main app's
    /// own nearby-location lookup. Never requests location permission itself: a widget extension
    /// can't usefully prompt the user, so this only ever runs once the main app has already
    /// obtained "when in use" access.
    static func fetchNearbySnapshot() async -> WeatherWidgetSnapshot? {
        guard let baseURL else { return nil }

        let status = CLLocationManager().authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else { return nil }
        guard let coordinate = try? await LocationService().requestCurrentLocation() else { return nil }

        var components = URLComponents(url: baseURL.appendingPathComponent("api/v1/weather/nearby"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "lat", value: String(coordinate.latitude)),
            URLQueryItem(name: "lon", value: String(coordinate.longitude)),
        ]
        guard let url = components?.url,
              let (data, response) = try? await URLSession.shared.data(from: url),
              let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode),
              let raw = try? JSONDecoder().decode(RawWeatherResponse.self, from: data),
              let observedAt = BackendDateFormatters.parseInstant(raw.observedAt)
        else { return nil }

        // Best-effort: today's sunrise/sunset (only on /forecast, not /nearby itself) is what
        // WeatherCardView also relies on to know it's night -- a failure here just means the
        // widget renders as if it were day, same fallback WeatherConditionStyle itself uses when
        // it has no sunrise/sunset on hand.
        let isNight = await fetchIsNight(city: raw.city, baseURL: baseURL, observedAt: observedAt)

        return raw.snapshot(observedAt: observedAt, isNight: isNight)
    }

    private static func fetchIsNight(city: String, baseURL: URL, observedAt: Date) async -> Bool {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/v1/weather/forecast"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "city", value: city)]
        guard let url = components?.url,
              let (data, response) = try? await URLSession.shared.data(from: url),
              let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode),
              let forecast = try? JSONDecoder().decode(RawForecastResponse.self, from: data),
              let today = forecast.daily.first,
              let sunrise = BackendDateFormatters.parseInstant(today.sunrise),
              let sunset = BackendDateFormatters.parseInstant(today.sunset)
        else { return false }

        return observedAt < sunrise || observedAt > sunset
    }
}

private struct RawWeatherResponse: Decodable {
    let city: String
    let country: String
    let temperature: Double
    let feelsLike: Double
    let humidity: Int
    let windSpeed: Double
    let description: String
    let units: Units
    let observedAt: String

    func snapshot(observedAt: Date, isNight: Bool) -> WeatherWidgetSnapshot {
        WeatherWidgetSnapshot(
            city: city,
            country: country,
            temperature: temperature,
            feelsLike: feelsLike,
            humidity: humidity,
            windSpeed: windSpeed,
            description: description,
            temperatureSymbol: units.temperatureSymbol,
            windSpeedSymbol: units.windSpeedSymbol,
            lastUpdated: observedAt,
            isNight: isNight
        )
    }
}

/// Only the fields needed to know whether it's currently night for the city's timezone.
private struct RawForecastResponse: Decodable {
    let daily: [Daily]

    struct Daily: Decodable {
        let sunrise: String
        let sunset: String
    }
}
