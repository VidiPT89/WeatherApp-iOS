import Foundation

/// Bridges the network model to the widget's tiny persisted shape. Kept out of `Shared/`
/// (compiled into the widget extension too) because `WeatherResponse` isn't -- the extension only
/// ever reads an already-built `WeatherWidgetSnapshot`, it doesn't need to know how one is made.
extension WeatherWidgetSnapshot {
    init(weather: WeatherResponse) {
        self.init(
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
    }
}
