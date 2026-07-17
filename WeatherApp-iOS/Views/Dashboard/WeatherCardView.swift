import SwiftUI

/// Current-conditions card: city/country, big temperature, description,
/// feels-like/humidity/wind, and the cache badge. Background gradient varies
/// by weather condition via `WeatherConditionStyle`. The fallback banner is
/// rendered by the caller above/below this card, not inside it, since it's a
/// cross-cutting concern rather than part of "current conditions".
struct WeatherCardView: View {
    let weather: WeatherResponse

    private var style: WeatherConditionStyle.Style {
        WeatherConditionStyle.style(for: weather.description)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(weather.city)
                        .font(.title2.bold())
                    Text(weather.country)
                        .font(.subheadline)
                        .opacity(0.85)
                }
                Spacer()
                Image(systemName: style.symbolName)
                    .font(.system(size: 40))
                    .symbolRenderingMode(.multicolor)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(formattedTemperature(weather.temperature))
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                Text(weather.units.temperatureSymbol)
                    .font(.title2)
                    .opacity(0.85)
            }

            Text(weather.description.capitalized)
                .font(.headline)

            HStack(spacing: 20) {
                metric(label: "Sensação", value: "\(formattedTemperature(weather.feelsLike))\(weather.units.temperatureSymbol)")
                metric(label: "Humidade", value: "\(weather.humidity)%")
                metric(label: "Vento", value: "\(formattedTemperature(weather.windSpeed)) \(weather.units.windSpeedSymbol)")
            }

            CacheBadgeView(fromCache: weather.fromCache, observedAt: weather.observedAt)
        }
        .padding(20)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: style.gradient, startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 20)
        )
        // Deliberately no `.accessibilityIdentifier` on this container: SwiftUI
        // pushes a container-level identifier down onto every descendant leaf
        // that doesn't already have a *more specific* one winning, which was
        // observed clobbering CacheBadgeView's own identifiers in UI tests.
        // Tests key off visible text (city name / cache badge copy) instead.
    }

    private func metric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.semibold))
            Text(label)
                .font(.caption2)
                .opacity(0.85)
        }
    }

    private func formattedTemperature(_ value: Double) -> String {
        String(format: "%.0f", value)
    }
}

#Preview {
    WeatherCardView(weather: WeatherResponse(
        city: "Lisboa",
        country: "Portugal",
        temperature: 24.3,
        feelsLike: 25.1,
        humidity: 60,
        windSpeed: 12.4,
        description: "clear sky",
        units: .metric,
        provider: "open-meteo",
        observedAt: .now,
        fromCache: false
    ))
    .padding()
}
