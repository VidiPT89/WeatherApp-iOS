import SwiftUI

/// Expanded "sea conditions" sheet opened by tapping `MarineConditionsView`.
/// The compact card packs every tide event into a single horizontally
/// scrolling row -- easy to miss entries off-screen. This lays the same
/// `marine.tideEvents` out as a plain vertical list (nothing scrolls past
/// the edge unnoticed) alongside water temperature/swell with a short
/// explanation of what each figure means.
struct MarineDetailView: View {
    let marine: MarineResponse

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    if marine.hasData {
                        VStack(alignment: .leading, spacing: 12) {
                            sectionTitle("Água e ondulação")
                            detailRow(icon: "thermometer.medium", label: "Temperatura da água", value: formattedWaterTemperature, note: "Temperatura à superfície do mar.")
                            detailRow(icon: "ruler", label: "Altura das ondas", value: formattedWaveHeight)
                            detailRow(icon: "arrow.up.right.circle", label: "Direção da ondulação", value: formattedWaveDirection, note: "Graus a partir do Norte -- de onde a ondulação vem.")
                            detailRow(icon: "timer", label: "Período da ondulação", value: formattedWavePeriod, note: "Tempo entre ondas consecutivas -- períodos maiores costumam indicar ondulação mais organizada.")
                        }
                    } else {
                        Label("Sem dados marítimos para esta localização.", systemImage: "mappin.slash")
                            .font(.subheadline)
                            .foregroundStyle(Color("TextSecondary"))
                    }

                    if !marine.tideEvents.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 10) {
                            sectionTitle("Marés de hoje")
                            Text("Estimativa calculada a partir da série horária de nível do mar -- não é uma tabela de marés oficial.")
                                .font(.caption2)
                                .foregroundStyle(Color("TextSecondary"))

                            ForEach(Array(marine.tideEvents.enumerated()), id: \.offset) { _, event in
                                HStack(spacing: 12) {
                                    Image(systemName: event.isHigh ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                        .foregroundStyle(event.isHigh ? .blue : .cyan)
                                        .font(.title3)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(event.isHigh ? "Maré alta" : "Maré baixa")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Color("TextPrimary"))
                                        Text(formattedTideTime(event.time))
                                            .font(.caption)
                                            .foregroundStyle(Color("TextSecondary"))
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                                if event.time != marine.tideEvents.last?.time {
                                    Divider()
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Color("Background").ignoresSafeArea())
            .navigationTitle(marine.city)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fechar") { dismiss() }
                        .accessibilityIdentifier("marineDetail.close")
                }
            }
        }
    }

    private var header: some View {
        Label("Condições marítimas", systemImage: "water.waves")
            .font(.title3.weight(.semibold))
            .foregroundStyle(Color("TextPrimary"))
    }

    private func sectionTitle(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color("TextPrimary"))
    }

    private func detailRow(icon: String, label: LocalizedStringKey, value: String?, note: String? = nil) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(Color.accentColor)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(Color("TextSecondary"))
                Text(value ?? "—")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color("TextPrimary"))
                if let note {
                    Text(note)
                        .font(.caption2)
                        .foregroundStyle(Color("TextSecondary"))
                }
            }
            Spacer()
        }
    }

    private var formattedWaterTemperature: String? {
        guard let value = marine.waterTemperature else { return nil }
        return "\(NumberFormatting.roundedWhole(value))\(marine.units.temperatureSymbol)"
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
        return "\(NumberFormatting.roundedWhole(value))°"
    }

    private var formattedWavePeriod: String? {
        guard let value = marine.wavePeriodSeconds else { return nil }
        return String(format: "%.1fs", value)
    }

    private func formattedTideTime(_ time: String) -> String {
        time.split(separator: "T").last.map(String.init) ?? time
    }
}

#Preview {
    MarineDetailView(marine: MarineResponse(
        city: "Lisbon", country: "Portugal", units: .metric, provider: "open-meteo", fromCache: false,
        waterTemperature: 20.3, waveHeightMeters: 0.4, waveDirectionDegrees: 282.0, wavePeriodSeconds: 5.8,
        tideEvents: [
            TideEvent(type: "low", time: "2026-07-24T05:00"),
            TideEvent(type: "high", time: "2026-07-24T11:00"),
            TideEvent(type: "low", time: "2026-07-24T17:15"),
            TideEvent(type: "high", time: "2026-07-24T23:30"),
        ]
    ))
}
