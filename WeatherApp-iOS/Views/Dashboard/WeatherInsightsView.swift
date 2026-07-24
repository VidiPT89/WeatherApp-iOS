import SwiftUI

/// "More about today" card: moon phase, UV risk, outdoor-activity score and
/// (when available) fishing conditions — derived indicators computed
/// server-side from data already fetched for the dashboard.
struct WeatherInsightsView: View {
    let insights: WeatherInsightsResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Mais sobre hoje", systemImage: "sparkles")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color("TextPrimary"))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 16) {
                insight(
                    label: "Fase da lua",
                    value: Text(moonPhaseKey) + Text(verbatim: " · \(insights.moonPhase.illuminationPercent)%"),
                    tone: .neutral
                )
                insight(label: "Risco UV", value: Text(uvRiskKey), tone: uvRiskTone)
                insight(
                    label: "Atividades ao ar livre",
                    value: Text(activityKey) + Text(verbatim: " · \(insights.outdoorActivityScore)"),
                    tone: activityTone
                )
                if let fishingKey {
                    insight(label: "Condições de pesca", value: Text(fishingKey), tone: fishingTone)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("CardBackground"), in: RoundedRectangle(cornerRadius: 18))
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private enum Tone {
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

    private func insight(label: LocalizedStringKey, value: Text, tone: Tone) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color("TextSecondary"))
            value
                .font(.caption.weight(.semibold))
                .foregroundStyle(tone.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(tone.color.opacity(0.15), in: Capsule())
        }
    }

    /// The backend returns these as fixed English enum-like strings (not
    /// localized) — map each to a `LocalizedStringKey` so Xcode's String
    /// Catalog carries a PT/EN translation, same as the rest of the app.
    private var moonPhaseKey: LocalizedStringKey {
        switch insights.moonPhase.phase {
        case "New Moon": return "Lua Nova"
        case "Waxing Crescent": return "Crescente"
        case "First Quarter": return "Quarto Crescente"
        case "Waxing Gibbous": return "Gibosa Crescente"
        case "Full Moon": return "Lua Cheia"
        case "Waning Gibbous": return "Gibosa Minguante"
        case "Last Quarter": return "Quarto Minguante"
        case "Waning Crescent": return "Minguante"
        default: return LocalizedStringKey(insights.moonPhase.phase)
        }
    }

    private var uvRiskKey: LocalizedStringKey {
        switch insights.uvRiskLabel {
        case "Low": return "Baixo"
        case "Moderate": return "Moderado"
        case "High": return "Alto"
        case "Very High": return "Muito Alto"
        case "Extreme": return "Extremo"
        default: return LocalizedStringKey(insights.uvRiskLabel)
        }
    }

    private var activityKey: LocalizedStringKey {
        switch insights.outdoorActivityLabel {
        case "Great": return "Ótimo"
        case "Good": return "Bom"
        case "Fair": return "Razoável"
        case "Poor": return "Fraco"
        default: return LocalizedStringKey(insights.outdoorActivityLabel)
        }
    }

    private var fishingKey: LocalizedStringKey? {
        switch insights.fishingConditionLabel {
        case "Good": return "Boas"
        case "Fair": return "Razoáveis"
        case "Poor": return "Fracas"
        case nil: return nil
        case let .some(other): return LocalizedStringKey(other)
        }
    }

    private var uvRiskTone: Tone {
        switch insights.uvRiskLabel {
        case "Low": return .good
        case "Moderate": return .neutral
        case "High", "Very High": return .warn
        case "Extreme": return .bad
        default: return .neutral
        }
    }

    private var activityTone: Tone {
        switch insights.outdoorActivityLabel {
        case "Great", "Good": return .good
        case "Fair": return .neutral
        case "Poor": return .bad
        default: return .neutral
        }
    }

    private var fishingTone: Tone {
        switch insights.fishingConditionLabel {
        case "Good": return .good
        case "Fair": return .neutral
        case "Poor": return .bad
        default: return .neutral
        }
    }
}

#Preview("Coastal") {
    WeatherInsightsView(insights: WeatherInsightsResponse(
        city: "Cascais", country: "Portugal",
        moonPhase: MoonPhaseInfo(phase: "Waxing Gibbous", illuminationPercent: 76),
        uvRiskLabel: "High",
        outdoorActivityScore: 88, outdoorActivityLabel: "Great",
        fishingConditionLabel: "Fair"
    ))
    .padding()
}

#Preview("Inland") {
    WeatherInsightsView(insights: WeatherInsightsResponse(
        city: "Madrid", country: "Spain",
        moonPhase: MoonPhaseInfo(phase: "Waxing Gibbous", illuminationPercent: 76),
        uvRiskLabel: "Very High",
        outdoorActivityScore: 73, outdoorActivityLabel: "Good",
        fishingConditionLabel: nil
    ))
    .padding()
}
