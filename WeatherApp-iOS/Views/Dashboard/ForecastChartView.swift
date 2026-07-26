import SwiftUI
import Charts

/// Forecast chart with a segmented control switching between hourly
/// (line/area, 48 points over 2 days) and daily (bar, min+max per day, 16
/// days). Both ranges use Chart's native `chartScrollableAxes` horizontal
/// scrolling instead of truncating, since 48 hourly / 16 daily points don't
/// fit on screen at once.
struct ForecastChartView: View {
    let forecast: ForecastResponse
    @Binding var range: ForecastRange

    private static let visibleHourlyWindow: TimeInterval = 7 * 3600
    private static let visibleDailyWindow: TimeInterval = 6 * 86400

    // Explicit, app-owned scroll position, paired with the paging buttons
    // below. Repeated separate swipe gestures on the chart were observed to
    // reliably move it only once and then stop responding to further
    // swipes -- a swipe-specific gesture-recognition quirk, not something
    // that affects discrete taps. The paging buttons give a reliable way to
    // reach every day/hour regardless of that swipe behavior.
    @State private var hourlyScrollPosition: Date = .now
    @State private var dailyScrollPosition: Date = .now

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Intervalo", selection: $range.animation(.easeInOut)) {
                ForEach(ForecastRange.allCases) { range in
                    Text(range.titleKey).tag(range)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Text("Temperatura do ar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                pagingControls
            }

            Group {
                switch range {
                case .hourly:
                    hourlyChart
                case .daily:
                    dailyChart
                }
            }
            .transition(.opacity)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var pagingControls: some View {
        HStack(spacing: 16) {
            Button(action: pageBackward) {
                Image(systemName: "chevron.left.circle.fill")
            }
            .disabled(!canPageBackward)
            .accessibilityIdentifier("forecast.chart.pageBackward")

            Button(action: pageForward) {
                Image(systemName: "chevron.right.circle.fill")
            }
            .disabled(!canPageForward)
            .accessibilityIdentifier("forecast.chart.pageForward")
        }
        .font(.title3)
        .foregroundStyle(.blue)
    }

    private var canPageBackward: Bool {
        switch range {
        case .hourly:
            guard let first = forecast.hourly.first?.time else { return false }
            return hourlyScrollPosition > first
        case .daily:
            guard let first = forecast.daily.first?.date else { return false }
            return dailyScrollPosition > first
        }
    }

    private var canPageForward: Bool {
        switch range {
        case .hourly:
            guard let last = forecast.hourly.last?.time else { return false }
            return hourlyScrollPosition.addingTimeInterval(Self.visibleHourlyWindow) < last
        case .daily:
            guard let last = forecast.daily.last?.date else { return false }
            return dailyScrollPosition.addingTimeInterval(Self.visibleDailyWindow) < last
        }
    }

    private func pageBackward() {
        switch range {
        case .hourly:
            page(&hourlyScrollPosition, by: -Self.visibleHourlyWindow, first: forecast.hourly.first?.time, last: forecast.hourly.last?.time, window: Self.visibleHourlyWindow)
        case .daily:
            page(&dailyScrollPosition, by: -Self.visibleDailyWindow, first: forecast.daily.first?.date, last: forecast.daily.last?.date, window: Self.visibleDailyWindow)
        }
    }

    private func pageForward() {
        switch range {
        case .hourly:
            page(&hourlyScrollPosition, by: Self.visibleHourlyWindow, first: forecast.hourly.first?.time, last: forecast.hourly.last?.time, window: Self.visibleHourlyWindow)
        case .daily:
            page(&dailyScrollPosition, by: Self.visibleDailyWindow, first: forecast.daily.first?.date, last: forecast.daily.last?.date, window: Self.visibleDailyWindow)
        }
    }

    private func page(_ position: inout Date, by delta: TimeInterval, first: Date?, last: Date?, window: TimeInterval) {
        guard let first, let last else { return }
        let candidate = position.addingTimeInterval(delta)
        let latestAllowed = max(first, last.addingTimeInterval(-window))
        withAnimation(.easeInOut) {
            position = min(max(candidate, first), latestAllowed)
        }
    }

    private var hourlyChart: some View {
        Chart(forecast.hourly) { entry in
            AreaMark(
                x: .value("Hora", entry.time),
                y: .value("Temperatura", entry.temperature)
            )
            .foregroundStyle(.blue.opacity(0.15))
            .interpolationMethod(.catmullRom)

            LineMark(
                x: .value("Hora", entry.time),
                y: .value("Temperatura", entry.temperature)
            )
            .foregroundStyle(.blue)
            .interpolationMethod(.catmullRom)

            if entry.precipitationProbability >= 30 {
                PointMark(
                    x: .value("Hora", entry.time),
                    y: .value("Temperatura", entry.temperature)
                )
                .symbolSize(18)
                .foregroundStyle(.cyan)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 3)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour())
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let temperature = value.as(Double.self) {
                        Text("\(NumberFormatting.roundedWhole(temperature))\(forecast.units.temperatureSymbol)")
                    }
                }
            }
        }
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: Self.visibleHourlyWindow)
        .chartScrollPosition(x: $hourlyScrollPosition)
        .frame(height: 220)
        .accessibilityIdentifier("forecast.hourlyChart")
    }

    private var dailyChart: some View {
        Chart(forecast.daily) { entry in
            BarMark(
                x: .value("Dia", entry.date, unit: .day),
                yStart: .value("Mínima", entry.temperatureMin),
                yEnd: .value("Máxima", entry.temperatureMax),
                width: .fixed(28)
            )
            .foregroundStyle(.blue.gradient)
            .cornerRadius(6)
            .annotation(position: .top) {
                Text("\(NumberFormatting.roundedWhole(entry.temperatureMax))°")
                    .font(.caption2.weight(.semibold))
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisValueLabel(format: .dateTime.weekday(.abbreviated))
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let temperature = value.as(Double.self) {
                        Text("\(NumberFormatting.roundedWhole(temperature))\(forecast.units.temperatureSymbol)")
                    }
                }
            }
        }
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: Self.visibleDailyWindow)
        .chartScrollPosition(x: $dailyScrollPosition)
        .frame(height: 220)
        .accessibilityIdentifier("forecast.dailyChart")
    }
}

#Preview {
    ForecastChartView(
        forecast: ForecastResponse(
            city: "Lisboa", country: "Portugal", units: .metric, provider: "open-meteo", fromCache: false,
            hourly: (0..<48).map { hour in
                HourlyForecastEntry(
                    time: .now.addingTimeInterval(Double(hour) * 3600),
                    temperature: 18 + Double(hour % 6),
                    description: "clear",
                    precipitationProbability: (hour * 7) % 100
                )
            },
            daily: (0..<16).map { day in
                DailyForecastEntry(
                    date: .now.addingTimeInterval(Double(day) * 86400),
                    temperatureMax: 24, temperatureMin: 15, description: "clear",
                    sunrise: .now, sunset: .now, uvIndexMax: 5, precipitationProbabilityMax: 20
                )
            }
        ),
        range: .constant(.hourly)
    )
    .padding()
}
