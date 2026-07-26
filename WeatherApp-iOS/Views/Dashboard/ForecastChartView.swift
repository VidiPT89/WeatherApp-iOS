import SwiftUI
import Charts

/// Forecast chart with a segmented control switching between hourly
/// (line/area, 48 points over 2 days) and daily (bar, min+max per day, 16
/// days). Both ranges use Chart's native `chartScrollableAxes` horizontal
/// scrolling instead of truncating, since 48 hourly / 16 daily points don't
/// fit on screen at once.
///
/// Design intent: this isn't just for a casual glance -- shore fishermen and
/// surfers rely on it too, so every value that matters (min/max, rain
/// chance, "which day/hour is this") is labeled directly on the chart
/// instead of requiring the reader to cross-reference the axis by eye.
struct ForecastChartView: View {
    let forecast: ForecastResponse
    @Binding var range: ForecastRange

    private static let visibleHourlyWindow: TimeInterval = 7 * 3600
    private static let visibleDailyWindow: TimeInterval = 6 * 86400
    private static let coolColor = Color(red: 0.20, green: 0.55, blue: 0.95)
    private static let warmColor = Color(red: 0.95, green: 0.35, blue: 0.20)
    // Every other label in this view is a hardcoded PT string; date/time
    // components must match rather than following the device's own locale
    // (which showed English month/weekday names on an English-locale
    // simulator otherwise).
    private static let ptLocale = Locale(identifier: "pt_PT")

    // Explicit, app-owned scroll position, paired with the paging buttons
    // below. Repeated separate swipe gestures on the chart were observed to
    // reliably move it only once and then stop responding to further
    // swipes -- a swipe-specific gesture-recognition quirk, not something
    // that affects discrete taps. The paging buttons give a reliable way to
    // reach every day/hour regardless of that swipe behavior.
    @State private var hourlyScrollPosition: Date = .now
    // Daily bars are one full day wide, anchored at midnight -- starting the
    // scroll position at `.now` (partway through today) clipped the left
    // edge of today's bar. Starting at midnight shows it in full.
    @State private var dailyScrollPosition: Date = Calendar.current.startOfDay(for: .now)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Intervalo", selection: $range.animation(.easeInOut)) {
                ForEach(ForecastRange.allCases) { range in
                    Text(range.titleKey).tag(range)
                }
            }
            .pickerStyle(.segmented)

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Temperatura do ar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(visibleRangeLabel)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    if range == .hourly {
                        Text("Agora: \(Date.now.formatted(.dateTime.hour().minute().locale(Self.ptLocale)))")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                }
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

    private var visibleRangeLabel: String {
        switch range {
        case .hourly:
            let end = hourlyScrollPosition.addingTimeInterval(Self.visibleHourlyWindow)
            let dayMonthHour: Date.FormatStyle = .dateTime.day().month(.abbreviated).hour().locale(Self.ptLocale)
            let hourOnly: Date.FormatStyle = .dateTime.hour().locale(Self.ptLocale)
            return "\(hourlyScrollPosition.formatted(dayMonthHour)) – \(end.formatted(hourOnly))"
        case .daily:
            let end = dailyScrollPosition.addingTimeInterval(Self.visibleDailyWindow)
            let dayMonth: Date.FormatStyle = .dateTime.day().month(.abbreviated).locale(Self.ptLocale)
            return "\(dailyScrollPosition.formatted(dayMonth)) – \(end.formatted(dayMonth))"
        }
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

    /// Interpolates cool->warm across this chart's own data range, so the
    /// hottest day/hour in the current forecast always reads as "warm" and
    /// the coolest as "cool", regardless of the units or absolute values --
    /// a quick color scan matters more here than precise degrees.
    private static func temperatureColor(_ value: Double, min: Double, max: Double) -> Color {
        guard max > min else { return coolColor }
        let t = ((value - min) / (max - min)).clamped(to: 0...1)
        return Color(
            red: coolColor.components.red + (warmColor.components.red - coolColor.components.red) * t,
            green: coolColor.components.green + (warmColor.components.green - coolColor.components.green) * t,
            blue: coolColor.components.blue + (warmColor.components.blue - coolColor.components.blue) * t
        )
    }

    private var hourlyChart: some View {
        let temperatures = forecast.hourly.map(\.temperature)
        let minTemp = temperatures.min() ?? 0
        let maxTemp = temperatures.max() ?? 1
        let tempRange = max(maxTemp - minTemp, 1)
        let precipitationBandHeight = tempRange * 0.18

        return Chart {
            ForEach(forecast.hourly) { entry in
                // Rain-chance bars anchored to the bottom of the chart, in
                // their own band beneath the temperature line -- mirrors the
                // Android chart so both platforms show rain likelihood the
                // same way.
                if entry.precipitationProbability > 0 {
                    BarMark(
                        x: .value("Hora", entry.time),
                        yStart: .value("Base", minTemp),
                        yEnd: .value("Chuva", minTemp + precipitationBandHeight * (Double(entry.precipitationProbability) / 100)),
                        width: .fixed(5)
                    )
                    .foregroundStyle(.cyan.opacity(0.4))
                }

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

                if isLabeledHourlyTick(entry.time) {
                    PointMark(
                        x: .value("Hora", entry.time),
                        y: .value("Temperatura", entry.temperature)
                    )
                    .symbolSize(28)
                    .foregroundStyle(.blue)
                    .annotation(position: .top) {
                        Text("\(NumberFormatting.roundedWhole(entry.temperature))°")
                            .font(.caption2.weight(.semibold))
                    }
                }
            }

            // Added once, outside the per-entry ForEach, so it draws exactly
            // one "now" marker rather than one per hourly entry. No
            // `.annotation` here: attaching a text annotation to a
            // full-height RuleMark made Charts pad the Y-domain to make
            // room for it (observed pushing a ~30°C dataset's axis to
            // 60°C) -- the "Agora" label lives in the header instead.
            RuleMark(x: .value("Agora", Date.now))
                .foregroundStyle(.orange)
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 3)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour().locale(Self.ptLocale))
                if let date = value.as(Date.self), Calendar.current.component(.hour, from: date) == 0 {
                    AxisValueLabel {
                        Text(date.formatted(.dateTime.weekday(.abbreviated).locale(Self.ptLocale)))
                            .font(.caption2.weight(.semibold))
                    }
                }
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
        .frame(height: 240)
        .accessibilityIdentifier("forecast.hourlyChart")
    }

    /// Only every 3rd hour gets a point + label, matching the axis ticks --
    /// labeling all 48 points would overlap into an unreadable smear.
    private func isLabeledHourlyTick(_ date: Date) -> Bool {
        Calendar.current.component(.hour, from: date).isMultiple(of: 3)
    }

    private var dailyChart: some View {
        let overallMin = forecast.daily.map(\.temperatureMin).min() ?? 0
        let overallMax = forecast.daily.map(\.temperatureMax).max() ?? 1

        return Chart(forecast.daily) { entry in
            BarMark(
                x: .value("Dia", entry.date, unit: .day),
                yStart: .value("Mínima", entry.temperatureMin),
                yEnd: .value("Máxima", entry.temperatureMax),
                width: .fixed(30)
            )
            .foregroundStyle(Self.temperatureColor(entry.temperatureMax, min: overallMin, max: overallMax))
            .cornerRadius(8)
            .annotation(position: .top) {
                Text("\(NumberFormatting.roundedWhole(entry.temperatureMax))°")
                    .font(.caption2.weight(.bold))
            }
            .annotation(position: .bottom) {
                Text("\(NumberFormatting.roundedWhole(entry.temperatureMin))°")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        let isToday = Calendar.current.isDateInToday(date)
                        Text(isToday ? "Hoje" : date.formatted(.dateTime.weekday(.abbreviated).locale(Self.ptLocale)))
                            .font(.caption2.weight(isToday ? .bold : .regular))
                            .foregroundStyle(isToday ? .orange : .secondary)
                    }
                }
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
        .frame(height: 240)
        .accessibilityIdentifier("forecast.dailyChart")
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

private extension Color {
    /// Best-effort sRGB component extraction for interpolating between two
    /// known, explicitly-constructed `Color(red:green:blue:)` values -- not
    /// intended for arbitrary system colors.
    var components: (red: Double, green: Double, blue: Double) {
        let uiColor = UIColor(self)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (Double(red), Double(green), Double(blue))
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
