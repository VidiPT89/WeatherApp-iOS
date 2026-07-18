import SwiftUI
import Charts

/// Forecast chart with a segmented control switching between hourly
/// (line/area, 48 points over 2 days) and daily (bar, min+max per day, 16
/// days). Both ranges scroll horizontally instead of truncating, since 48
/// hourly / 16 daily points don't fit on screen at once.
struct ForecastChartView: View {
    let forecast: ForecastResponse
    @Binding var range: ForecastRange

    private static let hourlyPointWidth: CGFloat = 52
    private static let dailyPointWidth: CGFloat = 64

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Intervalo", selection: $range.animation(.easeInOut)) {
                ForEach(ForecastRange.allCases) { range in
                    Text(range.titleKey).tag(range)
                }
            }
            .pickerStyle(.segmented)

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

    private var hourlyChart: some View {
        ScrollView(.horizontal, showsIndicators: false) {
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
            .frame(width: CGFloat(forecast.hourly.count) * Self.hourlyPointWidth, height: 220)
        }
    }

    private var dailyChart: some View {
        ScrollView(.horizontal, showsIndicators: false) {
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
                    Text("\(Int(entry.temperatureMax))°")
                        .font(.caption2.weight(.semibold))
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                }
            }
            .frame(width: CGFloat(forecast.daily.count) * Self.dailyPointWidth, height: 220)
        }
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
