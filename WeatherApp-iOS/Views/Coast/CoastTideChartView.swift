import Charts
import SwiftUI

/// The day's sea-level curve with its high and low tides marked, and a "now" line on today.
struct CoastTideChartView: View {
    let hours: [CoastHour]
    let tides: [(isHigh: Bool, time: Date)]
    let now: Date?

    private var points: [(time: Date, level: Double)] {
        hours.compactMap { hour in hour.seaLevelMeters.map { (hour.time, $0) } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Marés", systemImage: "arrow.up.and.down")
                .font(.headline)
                .foregroundStyle(Color("TextPrimary"))

            if points.count < 2 {
                Text("Sem dados de maré para este dia.")
                    .font(.subheadline)
                    .foregroundStyle(Color("TextSecondary"))
            } else {
                chart
                    .frame(height: 170)
                tideList
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("CardBackground"), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityIdentifier("coast.tideChart")
    }

    private var chart: some View {
        let low = points.map(\.level).min() ?? 0
        let high = points.map(\.level).max() ?? 1
        let padding = max((high - low) * 0.15, 0.05)
        return Chart {
            ForEach(points, id: \.time) { point in
                AreaMark(
                    x: .value("Hora", point.time),
                    yStart: .value("Base", low - padding),
                    yEnd: .value("Nível do mar", point.level))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(.linearGradient(
                        colors: [Color.accentColor.opacity(0.35), Color.accentColor.opacity(0.05)],
                        startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Hora", point.time), y: .value("Nível do mar", point.level))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color.accentColor)
            }
            ForEach(tides, id: \.time) { tide in
                if let level = level(at: tide.time) {
                    PointMark(x: .value("Hora", tide.time), y: .value("Nível do mar", level))
                        .foregroundStyle(tide.isHigh ? Color.accentColor : Color.orange)
                        .annotation(position: tide.isHigh ? .top : .bottom, spacing: 4) {
                            Text(tide.time, format: .dateTime.hour().minute())
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color("TextSecondary"))
                        }
                }
            }
            if let now {
                RuleMark(x: .value("Agora", now))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(Color("TextSecondary"))
            }
        }
        .chartYScale(domain: (low - padding)...(high + padding * 2))
        .chartXScale(domain: points[0].time...points[points.count - 1].time)
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 6)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour())
            }
        }
    }

    private var tideList: some View {
        HStack(spacing: 16) {
            ForEach(tides, id: \.time) { tide in
                VStack(alignment: .leading, spacing: 2) {
                    Text(tide.isHigh ? "Alta" : "Baixa")
                        .font(.caption)
                        .foregroundStyle(tide.isHigh ? Color.accentColor : Color.orange)
                    Text(tide.time, format: .dateTime.hour().minute())
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(Color("TextPrimary"))
                }
            }
        }
    }

    /// The tide events fall on whole hours of the same series, so the level is looked up directly.
    private func level(at time: Date) -> Double? {
        points.first { $0.time == time }?.level
    }
}
