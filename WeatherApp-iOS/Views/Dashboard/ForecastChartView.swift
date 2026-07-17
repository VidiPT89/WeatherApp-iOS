import SwiftUI
import Charts

/// Forecast chart with a segmented control switching between hourly
/// (line/area, ~72 points over 3 days) and daily (bar, min+max per day).
struct ForecastChartView: View {
    let forecast: ForecastResponse
    @Binding var range: ForecastRange

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Intervalo", selection: $range) {
                ForEach(ForecastRange.allCases) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)

            switch range {
            case .hourly:
                hourlyChart
            case .daily:
                dailyChart
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
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
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 12)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour())
            }
        }
        .frame(height: 220)
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
                Text("\(Int(entry.temperatureMax))°")
                    .font(.caption2.weight(.semibold))
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                AxisValueLabel(format: .dateTime.weekday(.abbreviated))
            }
        }
        .frame(height: 220)
    }
}

#Preview {
    ForecastChartView(
        forecast: ForecastResponse(
            city: "Lisboa", country: "Portugal", units: .metric, provider: "open-meteo", fromCache: false,
            hourly: (0..<24).map { hour in
                HourlyForecastEntry(time: .now.addingTimeInterval(Double(hour) * 3600), temperature: 18 + Double(hour % 6), description: "clear")
            },
            daily: (0..<3).map { day in
                DailyForecastEntry(date: .now.addingTimeInterval(Double(day) * 86400), temperatureMax: 24, temperatureMin: 15, description: "clear")
            }
        ),
        range: .constant(.hourly)
    )
    .padding()
}
