import WidgetKit
import SwiftUI

@main
struct WeatherWidgetBundle: WidgetBundle {
    var body: some Widget {
        WeatherWidget()
    }
}

/// Shows the last weather the main app itself fetched -- see
/// `WeatherWidgetProvider`'s doc comment for the "app-driven, no independent
/// fetching" scope decision.
struct WeatherWidget: Widget {
    let kind: String = "WeatherWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WeatherWidgetProvider()) { entry in
            WeatherWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Tempo")
        .description("Mostra o último tempo que consultaste na app.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
