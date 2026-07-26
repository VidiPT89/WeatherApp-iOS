import SwiftUI

/// Maps the backend's fixed English enum-like condition labels (uv risk,
/// outdoor activity, fishing, surf) to a localized key and a color tone.
/// Shared between `WeatherInsightsView` (today only) and the daily forecast's
/// per-day insight rows (all 16 days), since both surface the same vocabulary.
enum ConditionTone {
    case neutral, good, warn, bad

    var color: Color {
        switch self {
        case .neutral: return .secondary
        case .good: return .green
        case .warn: return .orange
        case .bad: return .red
        }
    }
}

enum ConditionLabels {
    static func uvRisk(_ label: String) -> LocalizedStringKey {
        switch label {
        case "Low": return "Baixo"
        case "Moderate": return "Moderado"
        case "High": return "Alto"
        case "Very High": return "Muito Alto"
        case "Extreme": return "Extremo"
        default: return LocalizedStringKey(label)
        }
    }

    static func uvRiskTone(_ label: String) -> ConditionTone {
        switch label {
        case "Low": return .good
        case "Moderate": return .neutral
        case "High", "Very High": return .warn
        case "Extreme": return .bad
        default: return .neutral
        }
    }

    static func outdoorActivity(_ label: String) -> LocalizedStringKey {
        switch label {
        case "Great": return "Ótimo"
        case "Good": return "Bom"
        case "Fair": return "Razoável"
        case "Poor": return "Fraco"
        default: return LocalizedStringKey(label)
        }
    }

    static func outdoorActivityTone(_ label: String) -> ConditionTone {
        switch label {
        case "Great", "Good": return .good
        case "Fair": return .neutral
        case "Poor": return .bad
        default: return .neutral
        }
    }

    static func fishingCondition(_ label: String?) -> LocalizedStringKey? {
        switch label {
        case "Good": return "Boas"
        case "Fair": return "Razoáveis"
        case "Poor": return "Fracas"
        case nil: return nil
        case let .some(other): return LocalizedStringKey(other)
        }
    }

    static func surfCondition(_ label: String?) -> LocalizedStringKey? {
        switch label {
        case "Good": return "Bom"
        case "Fair": return "Razoável"
        case "Poor": return "Fraco"
        case nil: return nil
        case let .some(other): return LocalizedStringKey(other)
        }
    }

    static func conditionTone(_ label: String?) -> ConditionTone {
        switch label {
        case "Good": return .good
        case "Fair": return .neutral
        case "Poor": return .bad
        default: return .neutral
        }
    }
}
