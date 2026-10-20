import SwiftUI

/// The Coast tab: favorite beaches first, then every other spot (nearest first when the user
/// shares their location), each opening its surf/fishing/beach outlook.
struct CoastSpotsView: View {
    @State private var viewModel = CoastSpotsViewModel()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Costa")
                .navigationDestination(for: CoastSpot.self) { spot in
                    CoastSpotDetailView(
                        spot: spot,
                        isFavorite: viewModel.isFavorite(spot),
                        onToggleFavorite: { viewModel.toggleFavorite(spot) })
                }
                .searchable(text: $viewModel.searchText, prompt: Text("Procurar praia ou localidade"))
                .refreshable { await viewModel.load() }
        }
        .task {
            if viewModel.spots.isEmpty {
                await viewModel.load()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.spots.isEmpty && viewModel.isLoading {
            VStack(spacing: 12) {
                ProgressView()
                Text("A procurar as praias perto de ti…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        } else if viewModel.spots.isEmpty, let errorMessage = viewModel.errorMessage {
            ContentUnavailableView {
                Label("Sem ligação", systemImage: "wifi.exclamationmark")
            } description: {
                Text(verbatim: errorMessage)
            } actions: {
                Button("Tentar outra vez") { Task { await viewModel.load() } }
                    .buttonStyle(.borderedProminent)
            }
        } else {
            List {
                if !viewModel.favoriteSpots.isEmpty {
                    Section {
                        ForEach(viewModel.favoriteSpots) { spot in row(spot) }
                    } header: {
                        Text("Favoritas")
                    }
                }
                Section {
                    ForEach(viewModel.otherSpots) { spot in row(spot) }
                } header: {
                    Text(viewModel.isSortedByDistance ? "Mais perto de ti" : "De norte a sul")
                } footer: {
                    if viewModel.favoriteSpots.isEmpty && viewModel.searchText.isEmpty {
                        Text("Desliza uma praia para a esquerda para a guardar nas favoritas.")
                    }
                }
            }
            .accessibilityIdentifier("coast.spotList")
        }
    }

    private func row(_ spot: CoastSpot) -> some View {
        NavigationLink(value: spot) {
            CoastSpotRow(spot: spot, isFavorite: viewModel.isFavorite(spot))
        }
        .swipeActions(edge: .trailing) {
            Button {
                viewModel.toggleFavorite(spot)
            } label: {
                if viewModel.isFavorite(spot) {
                    Label("Remover", systemImage: "star.slash")
                } else {
                    Label("Favorita", systemImage: "star")
                }
            }
            .tint(.yellow)
        }
    }
}

private struct CoastSpotRow: View {
    let spot: CoastSpot
    let isFavorite: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.15))
                Image(systemName: "water.waves")
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(verbatim: spot.name)
                        .font(.body.weight(.semibold))
                    if isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                            .accessibilityLabel(Text("Favorita"))
                    }
                }
                HStack(spacing: 6) {
                    if let area = spot.area {
                        Text(verbatim: area)
                    }
                    if let facing = spot.facingDegrees {
                        Text(verbatim: "·")
                        Text("Virada a \(Text(CoastLabels.compassPoint(Double(facing))))")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if let distance = spot.distanceKm {
                Text(verbatim: distance.formatted(.number.precision(.fractionLength(distance < 10 ? 1 : 0))) + " km")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    CoastSpotsView()
}
