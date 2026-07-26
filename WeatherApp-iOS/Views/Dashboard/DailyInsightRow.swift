import SwiftUI

/// Per-day signals below the daily forecast chart: rain chance, UV risk, and
/// (for coastal cities) fishing/surf conditions -- the temperature bars show
/// the trend, this shows what a shore fisherman or surfer actually needs to
/// decide whether the day is worth it.
///
/// Badges wrapped in their own horizontal `ScrollView` rather than a bare
/// `HStack`: a coastal day's full badge set (UV + fishing + surf, each with
/// an icon and a Portuguese label like "Muito Alto") measured wider than the
/// screen on some rows, and a bare HStack has no way to shrink -- it just
/// expands the whole card and clips it symmetrically on both edges. A
/// ScrollView guarantees the row can never force the card wider than the
/// screen, regardless of how long the labels get.
struct DailyInsightRow: View {
    let entry: DailyForecastEntry
    let isToday: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(isToday ? "Hoje" : dayLabel)
                    .font(.caption.weight(isToday ? .bold : .semibold))
                    .foregroundStyle(isToday ? .orange : .primary)
                    .frame(width: 40, alignment: .leading)

                badge(
                    icon: "cloud.rain.fill",
                    text: "\(entry.precipitationProbabilityMax)%",
                    tone: entry.rainLikely ? .warn : .neutral
                )
                Spacer(minLength: 0)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    badge(
                        icon: "sun.max.fill",
                        text: ConditionLabels.uvRisk(entry.uvRiskLabel),
                        tone: ConditionLabels.uvRiskTone(entry.uvRiskLabel)
                    )
                    if let fishingKey = ConditionLabels.fishingCondition(entry.fishingConditionLabel) {
                        badge(
                            icon: "fish.fill",
                            text: fishingKey,
                            tone: ConditionLabels.conditionTone(entry.fishingConditionLabel)
                        )
                    }
                    if let surfKey = ConditionLabels.surfCondition(entry.surfConditionLabel) {
                        badge(
                            icon: "figure.surfing",
                            text: surfKey,
                            tone: ConditionLabels.conditionTone(entry.surfConditionLabel)
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dayLabel: String {
        entry.date.formatted(.dateTime.weekday(.abbreviated).locale(Locale(identifier: "pt_PT")))
    }

    private func badge(icon: String, text: String, tone: ConditionTone) -> some View {
        Label(text, systemImage: icon)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tone.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tone.color.opacity(0.15), in: Capsule())
    }

    private func badge(icon: String, text: LocalizedStringKey, tone: ConditionTone) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: icon)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(tone.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tone.color.opacity(0.15), in: Capsule())
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 14) {
        DailyInsightRow(
            entry: DailyForecastEntry(
                date: .now, temperatureMax: 24, temperatureMin: 15, description: "clear",
                sunrise: .now, sunset: .now, uvIndexMax: 7, precipitationProbabilityMax: 15,
                windSpeedMax: 12, waveHeightMax: 0.6, wavePeriodMax: 9,
                rainLikely: false, uvRiskLabel: "High", outdoorActivityLabel: "Great",
                fishingConditionLabel: "Good", surfConditionLabel: "Good"
            ),
            isToday: true
        )
        Divider()
        DailyInsightRow(
            entry: DailyForecastEntry(
                date: .now.addingTimeInterval(86400), temperatureMax: 19, temperatureMin: 12, description: "rain",
                sunrise: .now, sunset: .now, uvIndexMax: 2, precipitationProbabilityMax: 80,
                windSpeedMax: 28, waveHeightMax: 3.2, wavePeriodMax: 5,
                rainLikely: true, uvRiskLabel: "Low", outdoorActivityLabel: "Poor",
                fishingConditionLabel: "Poor", surfConditionLabel: "Poor"
            ),
            isToday: false
        )
        Divider()
        DailyInsightRow(
            entry: DailyForecastEntry(
                date: .now.addingTimeInterval(86400 * 2), temperatureMax: 30, temperatureMin: 20, description: "clear",
                sunrise: .now, sunset: .now, uvIndexMax: 9, precipitationProbabilityMax: 0,
                windSpeedMax: 10, waveHeightMax: nil, wavePeriodMax: nil,
                rainLikely: false, uvRiskLabel: "Very High", outdoorActivityLabel: "Good",
                fishingConditionLabel: nil, surfConditionLabel: nil
            ),
            isToday: false
        )
    }
    .padding()
    .frame(width: 370)
}
