import SwiftUI
import WidgetKit

/// Widget content view -- switches on `\.widgetFamily` to lay out a compact
/// small size (city + temperature + condition icon) and a slightly fuller
/// medium size (adds feels-like/humidity). Both share the same
/// condition-based gradient background as `WeatherCardView`/`SplashView` in
/// the main app (via `WeatherConditionStyle`, compiled into this target too)
/// so the widget reads as the same app rather than a bolted-on extra.
struct WeatherWidgetEntryView: View {
    let entry: WeatherWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let snapshot = entry.snapshot {
            content(for: snapshot)
        } else {
            emptyState
        }
    }

    @ViewBuilder
    private func content(for snapshot: WeatherWidgetSnapshot) -> some View {
        switch family {
        case .systemMedium:
            mediumContent(snapshot)
        default:
            smallContent(snapshot)
        }
    }

    private func style(_ snapshot: WeatherWidgetSnapshot) -> WeatherConditionStyle.Style {
        WeatherConditionStyle.style(for: snapshot.description)
    }

    private func smallContent(_ snapshot: WeatherWidgetSnapshot) -> some View {
        let conditionStyle = style(snapshot)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(snapshot.city)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                Image(systemName: conditionStyle.symbolName)
                    .symbolRenderingMode(.multicolor)
            }
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(NumberFormatting.roundedWhole(snapshot.temperature))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text(snapshot.temperatureSymbol)
                    .font(.title3)
                    .opacity(0.85)
            }
            Text(snapshot.description.capitalized)
                .font(.caption2)
                .lineLimit(1)
                .opacity(0.9)
        }
        .foregroundStyle(.white)
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            LinearGradient(colors: conditionStyle.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private func mediumContent(_ snapshot: WeatherWidgetSnapshot) -> some View {
        let conditionStyle = style(snapshot)
        return HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(snapshot.city)
                    .font(.headline)
                    .lineLimit(1)
                Text(snapshot.country)
                    .font(.caption2)
                    .opacity(0.85)
                Spacer(minLength: 4)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(NumberFormatting.roundedWhole(snapshot.temperature))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                    Text(snapshot.temperatureSymbol)
                        .font(.title3)
                        .opacity(0.85)
                }
                Text(snapshot.description.capitalized)
                    .font(.caption)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                Image(systemName: conditionStyle.symbolName)
                    .font(.system(size: 30))
                    .symbolRenderingMode(.multicolor)
                Spacer()
                widgetMetric(icon: "thermometer.medium", text: "\(NumberFormatting.roundedWhole(snapshot.feelsLike))\(snapshot.temperatureSymbol)")
                widgetMetric(icon: "humidity.fill", text: "\(snapshot.humidity)%")
            }
        }
        .foregroundStyle(.white)
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            LinearGradient(colors: conditionStyle.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private func widgetMetric(icon: String, text: String) -> some View {
        Label {
            Text(text).font(.caption.weight(.semibold))
        } icon: {
            Image(systemName: icon).font(.caption2)
        }
        .opacity(0.9)
    }

    /// Shown before the app has ever successfully loaded weather (fresh
    /// install) -- a graceful placeholder rather than a crash or blank tile.
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "cloud.sun.fill")
                .font(.system(size: 28))
                .symbolRenderingMode(.multicolor)
            Text("Abre a app para veres o tempo aqui")
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) {
            Color(white: 0.92)
        }
    }
}

#Preview("Small", as: .systemSmall) {
    WeatherWidget()
} timeline: {
    WeatherWidgetEntry(date: .now, snapshot: WeatherWidgetProvider.placeholderSnapshot)
    WeatherWidgetEntry(date: .now, snapshot: nil)
}

#Preview("Medium", as: .systemMedium) {
    WeatherWidget()
} timeline: {
    WeatherWidgetEntry(date: .now, snapshot: WeatherWidgetProvider.placeholderSnapshot)
    WeatherWidgetEntry(date: .now, snapshot: nil)
}
