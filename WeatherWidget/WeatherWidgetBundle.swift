import WidgetKit
import SwiftUI

@main
struct WeatherWidgetBundle: WidgetBundle {
    var body: some Widget {
        WeatherWidget()
    }
}

/// Shows the latest weather snapshot, fetching its own when the app's is stale --
/// see `WeatherWidgetProvider`'s doc comment for how the two sources combine.
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
