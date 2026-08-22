import SwiftUI

/// Maps a weather `description` string to a background gradient and SF Symbol,
/// so the dashboard's weather card visually reflects current conditions.
/// Matching is a case-insensitive substring check against known keywords,
/// falling back to a neutral blue gradient for anything unrecognized.
enum WeatherConditionStyle {
    struct Style {
        let gradient: [Color]
        let symbolName: String
    }

    private static let rules: [(keywords: [String], style: Style, nightStyle: Style?)] = [
        (["thunderstorm", "trovoada"], Style(
            gradient: [Color(red: 0.14, green: 0.10, blue: 0.22), Color(red: 0.05, green: 0.04, blue: 0.09)],
            symbolName: "cloud.bolt.fill"
        ), nil),
        (["snow", "neve"], Style(
            gradient: [Color(red: 0.80, green: 0.88, blue: 0.96), Color(red: 0.93, green: 0.96, blue: 1.0)],
            symbolName: "snowflake"
        ), nil),
        (["fog", "mist", "haze", "nevoeiro", "névoa"], Style(
            gradient: [Color(red: 0.62, green: 0.65, blue: 0.68), Color(red: 0.78, green: 0.80, blue: 0.82)],
            symbolName: "cloud.fog.fill"
        ), nil),
        (["rain", "drizzle", "chuva", "chuvisco"], Style(
            gradient: [Color(red: 0.08, green: 0.18, blue: 0.36), Color(red: 0.16, green: 0.30, blue: 0.52)],
            symbolName: "cloud.rain.fill"
        ), nil),
        (["cloud", "overcast", "nublado", "nuvens"], Style(
            gradient: [Color(red: 0.55, green: 0.58, blue: 0.62), Color(red: 0.72, green: 0.75, blue: 0.78)],
            symbolName: "cloud.fill"
        ), Style(
            gradient: [Color(red: 0.16, green: 0.18, blue: 0.24), Color(red: 0.09, green: 0.10, blue: 0.15)],
            symbolName: "cloud.moon.fill"
        )),
        (["clear", "sunny", "limpo", "céu limpo"], Style(
            gradient: [Color(red: 0.20, green: 0.55, blue: 0.95), Color(red: 0.45, green: 0.78, blue: 0.98)],
            symbolName: "sun.max.fill"
        ), Style(
            gradient: [Color(red: 0.05, green: 0.07, blue: 0.20), Color(red: 0.12, green: 0.16, blue: 0.34)],
            symbolName: "moon.stars.fill"
        ))
    ]

    private static let fallback = Style(
        gradient: [Color(red: 0.25, green: 0.45, blue: 0.75), Color(red: 0.40, green: 0.60, blue: 0.85)],
        symbolName: "cloud.sun.fill"
    )
    private static let nightFallback = Style(
        gradient: [Color(red: 0.08, green: 0.10, blue: 0.22), Color(red: 0.14, green: 0.16, blue: 0.32)],
        symbolName: "cloud.moon.fill"
    )

    /// - Parameter isNight: whether `observedAt` falls outside `[sunrise, sunset]` for the
    ///   location -- e.g. Beja at 3am showing a bright "clear sky + sun" card was the exact bug
    ///   this parameter exists to fix. Defaults to `false` for call sites that don't have
    ///   sunrise/sunset data on hand (e.g. `/weather` alone, without today's forecast entry).
    static func style(for description: String, isNight: Bool = false) -> Style {
        let lowered = description.lowercased()
        for rule in rules where rule.keywords.contains(where: { lowered.contains($0) }) {
            if isNight, let nightStyle = rule.nightStyle {
                return nightStyle
            }
            return rule.style
        }
        return isNight ? nightFallback : fallback
    }
}
