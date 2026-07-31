import SwiftUI

/// Expanded "current conditions" sheet opened by tapping `WeatherCardView`.
/// Same data as the compact card (everything in `WeatherResponse`) plus the
/// day's fuller context from `today` (sunrise/sunset/UV/rain chance/max wind)
/// laid out with more room and a short explanatory line per metric, rather
/// than the compact card's dense grid.
struct WeatherDetailView: View {
    let weather: WeatherResponse
    var today: DailyForecastEntry?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    private var style: WeatherConditionStyle.Style {
        WeatherConditionStyle.style(for: weather.description)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    VStack(alignment: .leading, spacing: 12) {
                        sectionTitle("Condições agora")
                        detailRow(icon: "thermometer.medium", label: "Sensação térmica", value: "\(NumberFormatting.roundedWhole(weather.feelsLike))\(weather.units.temperatureSymbol)", note: Text("Como o corpo sente a temperatura, considerando vento e humidade."))
                        detailRow(icon: "humidity.fill", label: "Humidade", value: "\(weather.humidity)%")
                        detailRow(icon: "wind", label: "Vento", value: "\(NumberFormatting.roundedWhole(weather.windSpeed)) \(weather.units.windSpeedSymbol)")
                    }

                    if let today {
                        Divider()
                        VStack(alignment: .leading, spacing: 12) {
                            sectionTitle("Hoje")
                            detailRow(icon: "sunrise.fill", label: "Nascer do sol", value: formattedHour(today.sunrise))
                            detailRow(icon: "sunset.fill", label: "Pôr do sol", value: formattedHour(today.sunset))
                            detailRow(icon: "sun.max.trianglebadge.exclamationmark.fill", label: "Índice UV máximo", value: NumberFormatting.roundedWhole(today.uvIndexMax), note: Text("Risco: ") + Text(ConditionLabels.uvRisk(today.uvRiskLabel)))
                            detailRow(icon: "drop.fill", label: "Probabilidade de chuva", value: "\(today.precipitationProbabilityMax)%", note: Text(today.rainLikely ? "Chuva provável hoje." : "Chuva pouco provável hoje."))
                            detailRow(icon: "wind.circle", label: "Vento máximo previsto", value: "\(NumberFormatting.roundedWhole(today.windSpeedMax)) \(weather.units.windSpeedSymbol)")
                            detailRow(icon: "figure.outdoor.cycle", label: "Atividades ao ar livre", valueText: Text(ConditionLabels.outdoorActivity(today.outdoorActivityLabel)))
                        }
                    }

                    Divider()
                    VStack(alignment: .leading, spacing: 12) {
                        sectionTitle("Sobre estes dados")
                        detailRow(icon: weather.fromCache ? "clock.arrow.circlepath" : "checkmark.circle.fill", label: "Origem", value: weather.fromCache ? "Servido da cache" : "Dados frescos")
                        detailRow(icon: "server.rack", label: "Fornecedor", value: weather.provider.capitalized, note: weather.isFallbackProvider ? Text("Fornecedor secundário (o principal falhou nesta consulta).") : nil)
                        detailRow(icon: "calendar.badge.clock", label: "Observado em", value: formattedFullTimestamp(weather.observedAt))
                    }
                }
                .padding(20)
            }
            .background(Color("Background").ignoresSafeArea())
            .navigationTitle(weather.city)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fechar") { dismiss() }
                        .accessibilityIdentifier("weatherDetail.close")
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(weather.city).font(.title.bold())
                    Text(weather.country).font(.subheadline).opacity(0.85)
                }
                Spacer()
                Image(systemName: style.symbolName)
                    .font(.system(size: 44))
                    .symbolRenderingMode(.multicolor)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(NumberFormatting.roundedWhole(weather.temperature))
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                Text(weather.units.temperatureSymbol)
                    .font(.title)
                    .opacity(0.85)
            }

            Text(weather.description.capitalized)
                .font(.headline)
        }
        .padding(20)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .compositingGroup()
        .background(
            LinearGradient(colors: style.gradient, startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 20)
        )
    }

    private func sectionTitle(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color("TextPrimary"))
    }

    private func detailRow(icon: String, label: LocalizedStringKey, value: String, note: Text? = nil) -> some View {
        detailRow(icon: icon, label: label, valueText: Text(value), note: note)
    }

    private func detailRow(icon: String, label: LocalizedStringKey, valueText: Text, note: Text? = nil) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(Color.accentColor)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(Color("TextSecondary"))
                valueText
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color("TextPrimary"))
                if let note {
                    note
                        .font(.caption2)
                        .foregroundStyle(Color("TextSecondary"))
                }
            }
            Spacer()
        }
    }

    private func formattedHour(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale))
    }

    private func formattedFullTimestamp(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(locale))
    }
}

#Preview {
    WeatherDetailView(
        weather: WeatherResponse(
            city: "Lisboa", country: "Portugal", temperature: 24.3, feelsLike: 25.1,
            humidity: 60, windSpeed: 12.4, description: "clear sky", units: .metric,
            provider: "open-meteo", observedAt: .now, fromCache: false
        ),
        today: DailyForecastEntry(
            date: .now, temperatureMax: 26, temperatureMin: 16, description: "clear sky",
            sunrise: Calendar.current.date(bySettingHour: 7, minute: 12, second: 0, of: .now)!,
            sunset: Calendar.current.date(bySettingHour: 20, minute: 45, second: 0, of: .now)!,
            uvIndexMax: 6.4, precipitationProbabilityMax: 12,
            windSpeedMax: 14, waveHeightMax: 0.8, wavePeriodMax: 8.5,
            rainLikely: false, uvRiskLabel: "High", outdoorActivityLabel: "Great",
            fishingConditionLabel: "Good", surfConditionLabel: "Good"
        )
    )
}
