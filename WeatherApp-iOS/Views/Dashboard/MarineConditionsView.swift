import SwiftUI

/// "Sea conditions" card: water temperature and swell (height/direction/
/// period) for the searched city. Deliberately never says "tide" — the
/// backend doesn't provide real tide high/low times, only water temperature
/// and wave/swell data. Shows a graceful placeholder instead of an error
/// when every field comes back `nil` (inland/non-coastal cities).
struct MarineConditionsView: View {
    let marine: MarineResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Condições marítimas", systemImage: "water.waves")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color("TextPrimary"))

            if marine.hasData {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    metric(
                        icon: "thermometer.medium",
                        label: "Temp. da água",
                        value: formattedWaterTemperature
                    )
                    metric(
                        icon: "ruler",
                        label: "Altura das ondas",
                        value: formattedWaveHeight
                    )
                    metric(
                        icon: "arrow.up.right.circle",
                        label: "Direção",
                        value: formattedWaveDirection
                    )
                    metric(
                        icon: "timer",
                        label: "Período",
                        value: formattedWavePeriod
                    )
                }
            } else {
                Label("Sem dados marítimos para esta localização.", systemImage: "mappin.slash")
                    .font(.footnote)
                    .foregroundStyle(Color("TextSecondary"))
                    .padding(.vertical, 4)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("CardBackground"), in: RoundedRectangle(cornerRadius: 18))
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private func metric(icon: String, label: LocalizedStringKey, value: String?) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(Color.accentColor)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(value ?? "—")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color("TextPrimary"))
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(Color("TextSecondary"))
            }
        }
    }

    private var formattedWaterTemperature: String? {
        guard let value = marine.waterTemperature else { return nil }
        return "\(Int(value.rounded()))\(marine.units.temperatureSymbol)"
    }

    private var formattedWaveHeight: String? {
        guard let value = marine.waveHeightMeters else { return nil }
        if marine.units == .imperial {
            return String(format: "%.1f ft", value * 3.281)
        }
        return String(format: "%.1f m", value)
    }

    private var formattedWaveDirection: String? {
        guard let value = marine.waveDirectionDegrees else { return nil }
        return "\(Int(value.rounded()))°"
    }

    private var formattedWavePeriod: String? {
        guard let value = marine.wavePeriodSeconds else { return nil }
        return String(format: "%.1fs", value)
    }
}

#Preview("With data") {
    MarineConditionsView(marine: MarineResponse(
        city: "Lisbon", country: "Portugal", units: .metric, provider: "open-meteo", fromCache: false,
        waterTemperature: 20.3, waveHeightMeters: 0.4, waveDirectionDegrees: 282.0, wavePeriodSeconds: 5.8
    ))
    .padding()
}

#Preview("No data") {
    MarineConditionsView(marine: MarineResponse(
        city: "Madrid", country: "Spain", units: .metric, provider: "open-meteo", fromCache: false,
        waterTemperature: nil, waveHeightMeters: nil, waveDirectionDegrees: nil, wavePeriodSeconds: nil
    ))
    .padding()
}
