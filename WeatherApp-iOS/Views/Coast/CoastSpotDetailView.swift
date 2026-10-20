import SwiftUI

/// One beach: what the sea and wind are doing now, the best surf / fishing / beach-day window
/// for the chosen day and why, the tide curve, and an hour-by-hour strip.
struct CoastSpotDetailView: View {
    let isFavorite: Bool
    let onToggleFavorite: () -> Void

    @State private var viewModel: CoastOutlookViewModel
    @Environment(\.locale) private var locale

    init(spot: CoastSpot, isFavorite: Bool, onToggleFavorite: @escaping () -> Void) {
        self.isFavorite = isFavorite
        self.onToggleFavorite = onToggleFavorite
        _viewModel = State(initialValue: CoastOutlookViewModel(spot: spot))
    }

    private var units: Units {
        locale.measurementSystem == .us ? .imperial : .metric
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                content
            }
            .padding()
        }
        .background(Color("Background"))
        .navigationTitle(Text(verbatim: viewModel.spot.name))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onToggleFavorite) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .foregroundStyle(isFavorite ? .yellow : Color.accentColor)
                }
                .accessibilityLabel(isFavorite ? Text("Remover das favoritas") : Text("Guardar nas favoritas"))
                .accessibilityIdentifier("coast.favoriteButton")
            }
        }
        .task { await viewModel.load(units: units) }
        .refreshable { await viewModel.load(units: units) }
    }

    @ViewBuilder
    private var content: some View {
        if let outlook = viewModel.outlook {
            let now = outlook.spotNow()
            CoastNowCard(spot: viewModel.spot, outlook: outlook, now: now, units: units)

            if outlook.days.count > 1 {
                Picker(selection: $viewModel.selectedDayIndex) {
                    ForEach(Array(outlook.days.enumerated()), id: \.offset) { index, day in
                        dayLabel(day.date, index: index).tag(index)
                    }
                } label: {
                    Text("Dia")
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("coast.dayPicker")
            }

            if let day = viewModel.selectedDay {
                VStack(spacing: 12) {
                    ForEach(CoastActivity.allCases) { activity in
                        ActivityCard(activity: activity, window: day.window(for: activity))
                    }
                }

                CoastTideChartView(
                    hours: outlook.hours(on: day.date),
                    tides: outlook.tides(on: day.date),
                    now: Calendar.current.isDate(now, inSameDayAs: day.date) ? now : nil)

                CoastHourlyStripView(
                    hours: outlook.hours(on: day.date).filter { $0.time >= day.sunrise.addingTimeInterval(-3600) && $0.time <= day.sunset },
                    units: units)
            }

            Text("Estimativas calculadas a partir dos modelos da Open-Meteo, não são uma tabela de marés oficial. Confirma sempre as condições no local e respeita a bandeira e o nadador-salvador.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        } else if viewModel.isLoading {
            VStack(spacing: 12) {
                ProgressView()
                Text("A carregar o mar, o vento e as marés…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 80)
        } else if let errorMessage = viewModel.errorMessage {
            ContentUnavailableView {
                Label("Sem dados", systemImage: "exclamationmark.triangle")
            } description: {
                Text(verbatim: errorMessage)
            } actions: {
                Button("Tentar outra vez") { Task { await viewModel.load(units: units) } }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private func dayLabel(_ date: Date, index: Int) -> Text {
        switch index {
        case 0: return Text("Hoje")
        case 1: return Text("Amanhã")
        default: return Text(date, format: .dateTime.weekday(.abbreviated))
        }
    }
}

/// The conditions in the current hour: swell, wind (with offshore/onshore), water and next tide.
private struct CoastNowCard: View {
    let spot: CoastSpot
    let outlook: CoastOutlookResponse
    let now: Date
    let units: Units

    var body: some View {
        let hour = outlook.currentHour(now: now)
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                if let area = spot.area {
                    Text(verbatim: area)
                }
                if let facing = spot.facingDegrees {
                    Text(verbatim: "·")
                    Text("Virada a \(Text(CoastLabels.compassPoint(Double(facing))))")
                }
                Spacer()
                Text("Agora")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.15), in: Capsule())
            }
            .font(.subheadline)
            .foregroundStyle(Color("TextSecondary"))

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                GridRow {
                    metric(title: "Ondulação", symbol: "water.waves") {
                        if let height = hour?.swellHeightMeters ?? hour?.waveHeightMeters {
                            HStack(spacing: 4) {
                                Text(verbatim: CoastLabels.waveHeight(height, units: units))
                                if let period = hour?.swellPeriodSeconds ?? hour?.wavePeriodSeconds {
                                    Text(verbatim: "· \(Int(period.rounded())) s")
                                        .foregroundStyle(Color("TextSecondary"))
                                }
                                if let direction = hour?.swellDirectionDegrees ?? hour?.waveDirectionDegrees {
                                    DirectionArrow(fromDegrees: direction)
                                        .font(.caption)
                                }
                            }
                        } else {
                            Text(verbatim: "—")
                        }
                    }
                    metric(title: "Vento", symbol: "wind") {
                        if let speed = hour?.windSpeed {
                            HStack(spacing: 4) {
                                Text(verbatim: "\(Int(speed.rounded())) \(units.windSpeedSymbol)")
                                if let direction = hour?.windDirectionDegrees {
                                    DirectionArrow(fromDegrees: direction)
                                        .font(.caption)
                                }
                            }
                        } else {
                            Text(verbatim: "—")
                        }
                    }
                }
                GridRow {
                    metric(title: "Água", symbol: "thermometer.medium") {
                        if let water = hour?.waterTemperature {
                            Text(verbatim: "\(Int(water.rounded()))\(units.temperatureSymbol)")
                        } else {
                            Text(verbatim: "—")
                        }
                    }
                    metric(title: "Próxima maré", symbol: "arrow.up.and.down") {
                        if let tide = outlook.nextTide(after: now) {
                            HStack(spacing: 4) {
                                Text(tide.isHigh ? "Alta" : "Baixa")
                                Text(tide.time, format: .dateTime.hour().minute())
                            }
                        } else {
                            Text(verbatim: "—")
                        }
                    }
                }
            }

            if let exposure = CoastLabels.exposure(hour?.windExposure) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(CoastLabels.exposureColor(hour?.windExposure))
                        .frame(width: 8, height: 8)
                    Text("Vento \(Text(exposure)) nesta praia")
                        .font(.footnote)
                        .foregroundStyle(Color("TextSecondary"))
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("CardBackground"), in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("coast.nowCard")
    }

    private func metric<Value: View>(
        title: LocalizedStringKey, symbol: String, @ViewBuilder value: () -> Value
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(title, systemImage: symbol)
                .font(.caption)
                .foregroundStyle(Color("TextSecondary"))
            value()
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color("TextPrimary"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// One activity's verdict for the day: score band, best window and the reasons behind it.
private struct ActivityCard: View {
    let activity: CoastActivity
    let window: ActivityWindow?

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: CoastLabels.symbol(activity))
                .font(.title2)
                .foregroundStyle(window.map { CoastLabels.color($0.score) } ?? .secondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(CoastLabels.title(activity))
                        .font(.headline)
                        .foregroundStyle(Color("TextPrimary"))
                    Spacer()
                    if let window {
                        Text(CoastLabels.band(window.score))
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .foregroundStyle(CoastLabels.color(window.score))
                            .background(CoastLabels.color(window.score).opacity(0.15), in: Capsule())
                    }
                }
                if let window {
                    HStack(spacing: 4) {
                        Text("Melhor janela")
                        Text(window.start, format: .dateTime.hour().minute())
                        Text(verbatim: "–")
                        Text(window.end, format: .dateTime.hour().minute())
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color("TextPrimary"))

                    let reasons = window.reasons.compactMap(CoastLabels.reason)
                    if !reasons.isEmpty {
                        reasons.dropFirst().reduce(Text(reasons[0])) { result, reason in
                            result + Text(verbatim: " · ") + Text(reason)
                        }
                        .font(.footnote)
                        .foregroundStyle(Color("TextSecondary"))
                    }
                } else {
                    Text("Já não há horas de luz para hoje.")
                        .font(.subheadline)
                        .foregroundStyle(Color("TextSecondary"))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("CardBackground"), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("coast.activity.\(activity.rawValue)")
    }
}
