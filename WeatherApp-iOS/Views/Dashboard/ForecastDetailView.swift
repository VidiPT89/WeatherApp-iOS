import SwiftUI

/// Expanded forecast sheet opened by tapping `ForecastChartView`. The compact card's charts are
/// deliberately easy to skim, not precise -- this sheet trades that for an exact hour-by-hour /
/// day-by-day list of every value in the current `ForecastResponse`, for anyone who wants the
/// real numbers instead of eyeballing a line on a chart.
struct ForecastDetailView: View {
    let forecast: ForecastResponse
    let initialRange: ForecastRange

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var range: ForecastRange

    init(forecast: ForecastResponse, initialRange: ForecastRange) {
        self.forecast = forecast
        self.initialRange = initialRange
        _range = State(initialValue: initialRange)
    }

    private static let ptLocale = Locale(identifier: "pt_PT")

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Intervalo", selection: $range.animation(.easeInOut)) {
                    ForEach(ForecastRange.allCases) { range in
                        Text(range.titleKey).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                List {
                    switch range {
                    case .hourly:
                        ForEach(forecast.hourly) { entry in
                            hourlyRow(entry)
                        }
                    case .daily:
                        ForEach(forecast.daily) { entry in
                            dailyRow(entry)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .background(Color("Background").ignoresSafeArea())
            .navigationTitle("\(forecast.city) — previsão completa")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fechar") { dismiss() }
                        .accessibilityIdentifier("forecastDetail.close")
                }
            }
        }
    }

    private func hourlyRow(_ entry: HourlyForecastEntry) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(entry.time.formatted(.dateTime.weekday(.abbreviated).day().hour().minute().locale(Self.ptLocale)))
                .font(.subheadline)
                .foregroundStyle(Color("TextPrimary"))
            Spacer()
            if entry.precipitationProbability > 0 {
                Label("\(entry.precipitationProbability)%", systemImage: "drop.fill")
                    .font(.caption)
                    .foregroundStyle(.cyan)
            }
            Text(entry.description.capitalized)
                .font(.caption)
                .foregroundStyle(Color("TextSecondary"))
                .frame(width: 90, alignment: .trailing)
            Text("\(NumberFormatting.roundedWhole(entry.temperature))\(forecast.units.temperatureSymbol)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color("TextPrimary"))
                .frame(width: 48, alignment: .trailing)
        }
        .padding(.vertical, 2)
    }

    private func dailyRow(_ entry: DailyForecastEntry) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(Self.ptLocale)))
                    .font(.subheadline)
                    .foregroundStyle(Color("TextPrimary"))
                Text(entry.description.capitalized)
                    .font(.caption)
                    .foregroundStyle(Color("TextSecondary"))
            }
            Spacer()
            if entry.precipitationProbabilityMax > 0 {
                Label("\(entry.precipitationProbabilityMax)%", systemImage: "drop.fill")
                    .font(.caption)
                    .foregroundStyle(.cyan)
            }
            Text("\(NumberFormatting.roundedWhole(entry.temperatureMin))° / \(NumberFormatting.roundedWhole(entry.temperatureMax))\(forecast.units.temperatureSymbol)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color("TextPrimary"))
                .frame(width: 90, alignment: .trailing)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    ForecastDetailView(
        forecast: ForecastResponse(
            city: "Lisboa", country: "Portugal", units: .metric, provider: "open-meteo", fromCache: false,
            hourly: (0..<48).map { hour in
                HourlyForecastEntry(
                    time: .now.addingTimeInterval(Double(hour) * 3600),
                    temperature: 18 + Double(hour % 6),
                    description: "clear sky",
                    precipitationProbability: (hour * 7) % 100
                )
            },
            daily: (0..<16).map { day in
                DailyForecastEntry(
                    date: .now.addingTimeInterval(Double(day) * 86400),
                    temperatureMax: 24, temperatureMin: 15, description: "clear sky",
                    sunrise: .now, sunset: .now, uvIndexMax: 5, precipitationProbabilityMax: 20,
                    windSpeedMax: 15, waveHeightMax: 0.8, wavePeriodMax: 8,
                    rainLikely: false, uvRiskLabel: "Moderate", outdoorActivityLabel: "Good",
                    fishingConditionLabel: "Fair", surfConditionLabel: "Fair"
                )
            }
        ),
        initialRange: .hourly
    )
}
