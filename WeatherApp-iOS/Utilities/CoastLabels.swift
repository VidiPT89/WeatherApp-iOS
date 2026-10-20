import SwiftUI

/// Display text, symbols and colors for the coast outlook's codes (activities, score bands,
/// reason codes, wind exposure, compass points). Every label is a `LocalizedStringKey`, so it is
/// looked up in the string catalog with the in-app language.
enum CoastLabels {
    static func title(_ activity: CoastActivity) -> LocalizedStringKey {
        switch activity {
        case .surf: return "Surf"
        case .fishing: return "Pesca"
        case .beach: return "Praia"
        }
    }

    static func symbol(_ activity: CoastActivity) -> String {
        switch activity {
        case .surf: return "figure.surfing"
        case .fishing: return "fish.fill"
        case .beach: return "beach.umbrella.fill"
        }
    }

    static func band(_ score: Int) -> LocalizedStringKey {
        switch score {
        case 8...: return "Excelente"
        case 6..<8: return "Bom"
        case 4..<6: return "Razoável"
        default: return "Fraco"
        }
    }

    static func color(_ score: Int) -> Color {
        switch score {
        case 8...: return .green
        case 6..<8: return .teal
        case 4..<6: return .orange
        default: return .red
        }
    }

    static func reason(_ code: String) -> LocalizedStringKey? {
        switch code {
        case "SWELL_SHELTERED": return "Praia abrigada desta ondulação"
        case "FLAT": return "Sem ondas"
        case "SWELL_SMALL": return "Ondas pequenas"
        case "SWELL_FUN": return "Ondas boas para todos"
        case "SWELL_SOLID": return "Ondulação consistente"
        case "SWELL_BIG": return "Mar grande, só para experientes"
        case "SWELL_HUGE": return "Mar muito grande, perigoso"
        case "PERIOD_LONG": return "Período longo, ondas organizadas"
        case "PERIOD_SHORT": return "Período curto, mar desorganizado"
        case "WIND_OFFSHORE": return "Vento offshore"
        case "WIND_ONSHORE": return "Vento onshore"
        case "WIND_LIGHT": return "Vento fraco"
        case "WIND_STRONG": return "Vento forte"
        case "SEA_CALM": return "Mar calmo"
        case "SEA_MODERATE": return "Mar moderado"
        case "SEA_ROUGH": return "Mar agitado"
        case "TIDE_TURNING": return "Perto da mudança de maré"
        case "GOLDEN_HOUR": return "Nascer ou pôr do sol"
        case "WARM": return "Calor"
        case "COOL": return "Fresco"
        case "RAIN_LIKELY": return "Chuva provável"
        case "WATER_WARM": return "Água amena"
        case "WATER_COLD": return "Água fria"
        default: return nil
        }
    }

    static func exposure(_ value: String?) -> LocalizedStringKey? {
        switch value {
        case "offshore": return "Offshore"
        case "cross-shore": return "Cruzado"
        case "onshore": return "Onshore"
        default: return nil
        }
    }

    static func exposureColor(_ value: String?) -> Color {
        switch value {
        case "offshore": return .green
        case "onshore": return .orange
        default: return .secondary
        }
    }

    /// Eight-point compass name for a direction in degrees.
    static func compassPoint(_ degrees: Double) -> LocalizedStringKey {
        let points: [LocalizedStringKey] = ["N", "NE", "E", "SE", "S", "SO", "O", "NO"]
        let normalized = (degrees.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        return points[Int((normalized + 22.5) / 45) % 8]
    }

    /// Wave height in meters, or feet for imperial units.
    static func waveHeight(_ meters: Double, units: Units) -> String {
        switch units {
        case .metric: return meters.formatted(.number.precision(.fractionLength(1))) + " m"
        case .imperial: return (meters * 3.28084).formatted(.number.precision(.fractionLength(0))) + " ft"
        }
    }
}

/// An arrow pointing the way a wind or swell is travelling. Both come as the direction they
/// come FROM, so the arrow is turned a further 180 degrees.
struct DirectionArrow: View {
    let fromDegrees: Double

    var body: some View {
        Image(systemName: "location.north.fill")
            .rotationEffect(.degrees(fromDegrees + 180))
            .accessibilityHidden(true)
    }
}
