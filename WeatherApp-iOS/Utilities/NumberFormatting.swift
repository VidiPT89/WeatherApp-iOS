import Foundation

/// A single "round to the nearest whole number, no decimals" formatter shared by every card that
/// displays a raw `Double` from the API (temperature, wind speed, UV index, ...). Before this,
/// four different call sites each rounded independently -- two of them (`Int(value)`) truncated
/// instead of rounding, so the same 23.9° value could read as "24°" on one screen and "23°" on
/// another for no reason other than which spot happened to format it.
enum NumberFormatting {
    static func roundedWhole(_ value: Double) -> String {
        String(format: "%.0f", value)
    }
}
