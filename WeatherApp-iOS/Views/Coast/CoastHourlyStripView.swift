import SwiftUI

/// A horizontally scrolling hour-by-hour table: swell, period, wind (colored by offshore /
/// onshore) and a score dot per activity.
struct CoastHourlyStripView: View {
    let hours: [CoastHour]
    let units: Units

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Hora a hora", systemImage: "clock")
                .font(.headline)
                .foregroundStyle(Color("TextPrimary"))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    legend
                    ForEach(hours) { hour in
                        column(hour)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("CardBackground"), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityIdentifier("coast.hourlyStrip")
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(verbatim: " ").font(.caption)
            Image(systemName: "water.waves").frame(height: 18)
            Image(systemName: "timer").frame(height: 18)
            Image(systemName: "wind").frame(height: 34)
            ForEach(CoastActivity.allCases) { activity in
                Image(systemName: CoastLabels.symbol(activity)).frame(height: 14)
            }
        }
        .font(.caption)
        .foregroundStyle(Color("TextSecondary"))
        .padding(.trailing, 10)
    }

    private func column(_ hour: CoastHour) -> some View {
        VStack(spacing: 10) {
            Text(hour.time, format: .dateTime.hour())
                .font(.caption)
                .foregroundStyle(Color("TextSecondary"))

            Text(verbatim: (hour.swellHeightMeters ?? hour.waveHeightMeters)
                .map { CoastLabels.waveHeight($0, units: units) } ?? "—")
                .font(.caption.weight(.semibold))
                .frame(height: 18)

            Text(verbatim: (hour.swellPeriodSeconds ?? hour.wavePeriodSeconds)
                .map { "\(Int($0.rounded())) s" } ?? "—")
                .font(.caption)
                .frame(height: 18)

            VStack(spacing: 2) {
                if let direction = hour.windDirectionDegrees {
                    DirectionArrow(fromDegrees: direction)
                        .font(.caption2)
                }
                Text(verbatim: hour.windSpeed.map { "\(Int($0.rounded()))" } ?? "—")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(CoastLabels.exposureColor(hour.windExposure))
            .frame(height: 34)

            ForEach(CoastActivity.allCases) { activity in
                Circle()
                    .fill(hour.score(for: activity).map(CoastLabels.color) ?? Color.secondary.opacity(0.2))
                    .frame(width: 10, height: 10)
                    .frame(height: 14)
            }
        }
        .foregroundStyle(Color("TextPrimary"))
        .frame(width: 50)
    }
}
