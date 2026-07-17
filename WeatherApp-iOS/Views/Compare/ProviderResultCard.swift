import SwiftUI

/// One provider's card within the Compare screen: success shows
/// temp/description, failure shows the errorMessage in an error style.
struct ProviderResultCard: View {
    let result: ProviderComparisonResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(result.provider)
                    .font(.headline)
                if result.isPrimaryProvider {
                    Text("Principal")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.2), in: Capsule())
                        .foregroundStyle(.blue)
                }
                Spacer()
                Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(result.success ? .green : .red)
            }

            if result.success, let weather = result.weather {
                Text("\(Int(weather.temperature))\(weather.units.temperatureSymbol)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Text(weather.description.capitalized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text(result.errorMessage ?? "Erro desconhecido.")
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            result.success ? Color.secondary.opacity(0.08) : Color.red.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 14)
        )
    }
}

#Preview {
    VStack {
        ProviderResultCard(result: ProviderComparisonResult(
            provider: "open-meteo", success: true,
            weather: WeatherResponse(city: "Lisboa", country: "Portugal", temperature: 24, feelsLike: 25, humidity: 60, windSpeed: 10, description: "clear sky", units: .metric, provider: "open-meteo", observedAt: .now, fromCache: false),
            errorMessage: nil
        ))
        ProviderResultCard(result: ProviderComparisonResult(
            provider: "open-weather-map", success: false, weather: nil, errorMessage: "Provider unavailable"
        ))
    }
    .padding()
}
