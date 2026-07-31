import SwiftUI

/// Expanded "more about today" sheet opened by tapping `WeatherInsightsView`.
/// The compact card only ever shows today's moon phase/UV/activity/fishing
/// labels; `ForecastResponse.daily` already carries the same labels for all
/// 16 days, so this sheet earns its keep by showing the next several days at
/// once (reusing `DailyInsightRow`, the same per-day row already used under
/// the daily forecast chart, for visual consistency) instead of repeating
/// exactly what the card already said.
struct WeatherInsightsDetailView: View {
    let insights: WeatherInsightsResponse
    let dailyForecast: [DailyForecastEntry]

    /// A week's worth is enough to plan around without turning the sheet
    /// into a second copy of the full 16-day daily chart.
    private static let daysShown = 7

    @Environment(\.dismiss) private var dismiss

    private var visibleDays: [DailyForecastEntry] {
        Array(dailyForecast.prefix(Self.daysShown))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    moonPhaseHeader

                    if !visibleDays.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Próximos \(visibleDays.count) dias")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color("TextPrimary"))

                            ForEach(visibleDays) { entry in
                                DailyInsightRow(entry: entry, isToday: Calendar.current.isDateInToday(entry.date))
                                if entry.id != visibleDays.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Color("Background").ignoresSafeArea())
            .navigationTitle("Mais sobre hoje")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fechar") { dismiss() }
                        .accessibilityIdentifier("insightsDetail.close")
                }
            }
        }
    }

    private var moonPhaseHeader: some View {
        HStack(spacing: 14) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 32))
                .foregroundStyle(.indigo)
            VStack(alignment: .leading, spacing: 2) {
                Text(moonPhaseKey)
                    .font(.headline)
                Text("\(insights.moonPhase.illuminationPercent)% de iluminação")
                    .font(.caption)
                    .foregroundStyle(Color("TextSecondary"))
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("CardBackground"), in: RoundedRectangle(cornerRadius: 16))
    }

    private var moonPhaseKey: LocalizedStringKey {
        switch insights.moonPhase.phase {
        case "New Moon": return "Lua Nova"
        case "Waxing Crescent": return "Crescente"
        case "First Quarter": return "Quarto Crescente"
        case "Waxing Gibbous": return "Gibosa Crescente"
        case "Full Moon": return "Lua Cheia"
        case "Waning Gibbous": return "Gibosa Minguante"
        case "Last Quarter": return "Quarto Minguante"
        case "Waning Crescent": return "Minguante"
        default: return LocalizedStringKey(insights.moonPhase.phase)
        }
    }
}

#Preview {
    WeatherInsightsDetailView(
        insights: WeatherInsightsResponse(
            city: "Cascais", country: "Portugal",
            moonPhase: MoonPhaseInfo(phase: "Waxing Gibbous", illuminationPercent: 76),
            uvRiskLabel: "High",
            outdoorActivityScore: 88, outdoorActivityLabel: "Great",
            fishingConditionLabel: "Fair"
        ),
        dailyForecast: (0..<7).map { day in
            DailyForecastEntry(
                date: .now.addingTimeInterval(Double(day) * 86400), temperatureMax: 24, temperatureMin: 15, description: "clear",
                sunrise: .now, sunset: .now, uvIndexMax: 7, precipitationProbabilityMax: 15,
                windSpeedMax: 12, waveHeightMax: 0.6, wavePeriodMax: 9,
                rainLikely: false, uvRiskLabel: "High", outdoorActivityLabel: "Great",
                fishingConditionLabel: "Good", surfConditionLabel: "Good"
            )
        }
    )
}
