import SwiftUI

/// Current-conditions card: city/country, big temperature, description,
/// feels-like/humidity/wind, sunrise/sunset/UV/rain-chance (sourced from
/// today's daily forecast entry, since `/weather` itself doesn't carry
/// them), and the cache badge. Background gradient varies by weather
/// condition via `WeatherConditionStyle`. The fallback banner is rendered by
/// the caller above/below this card, not inside it, since it's a
/// cross-cutting concern rather than part of "current conditions".
struct WeatherCardView: View {
    let weather: WeatherResponse
    /// `forecast.daily[0]` — today's entry, carrying sunrise/sunset/UV/rain
    /// chance the `/weather` endpoint itself doesn't return. `nil` while the
    /// forecast hasn't loaded yet.
    var today: DailyForecastEntry?

    @Environment(\.locale) private var locale

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
                    .symbolEffect(.bounce, value: weather.city)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(formattedTemperature(weather.temperature))
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text(weather.units.temperatureSymbol)
                    .font(.title2)
                    .opacity(0.85)
            }
            .animation(.snappy, value: weather.temperature)

            Text(weather.description.capitalized)
                .font(.headline)

            HStack(spacing: 20) {
                metric(icon: "thermometer.medium", label: "Sensação", value: "\(formattedTemperature(weather.feelsLike))\(weather.units.temperatureSymbol)")
                metric(icon: "humidity.fill", label: "Humidade", value: "\(weather.humidity)%")
                metric(icon: "wind", label: "Vento", value: "\(formattedTemperature(weather.windSpeed)) \(weather.units.windSpeedSymbol)")
            }

            if let today {
                Divider().overlay(Color("Separator"))

                HStack(spacing: 20) {
                    metric(icon: "sunrise.fill", label: "Nascer do sol", value: formattedHour(today.sunrise))
                    metric(icon: "sunset.fill", label: "Pôr do sol", value: formattedHour(today.sunset))
                    metric(icon: "sun.max.trianglebadge.exclamationmark.fill", label: "Índice UV", value: String(format: "%.0f", today.uvIndexMax))
                    metric(icon: "drop.fill", label: "Prob. de chuva", value: "\(today.precipitationProbabilityMax)%")
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
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
        .animation(.easeInOut(duration: 0.4), value: today != nil)
        // Deliberately no `.accessibilityIdentifier` on this container: SwiftUI
        // pushes a container-level identifier down onto every descendant leaf
        // that doesn't already have a *more specific* one winning, which was
        // observed clobbering CacheBadgeView's own identifiers in UI tests.
        // Tests key off visible text (city name / cache badge copy) instead.
    }

    private func metric(icon: String, label: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label {
                Text(value)
                    .font(.subheadline.weight(.semibold))
            } icon: {
                Image(systemName: icon)
                    .font(.caption)
                    .opacity(0.85)
            }
            Text(label)
                .font(.caption2)
                .opacity(0.85)
        }
    }

    private func formattedTemperature(_ value: Double) -> String {
        String(format: "%.0f", value)
    }

    private func formattedHour(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale))
    }
}

#Preview {
    WeatherCardView(
        weather: WeatherResponse(
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
        ),
        today: DailyForecastEntry(
            date: .now, temperatureMax: 26, temperatureMin: 16, description: "clear sky",
            sunrise: Calendar.current.date(bySettingHour: 7, minute: 12, second: 0, of: .now)!,
            sunset: Calendar.current.date(bySettingHour: 20, minute: 45, second: 0, of: .now)!,
            uvIndexMax: 6.4, precipitationProbabilityMax: 12
        )
    )
    .padding()
}
