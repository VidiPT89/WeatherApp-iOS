import SwiftUI

/// Read-only search history, newest first.
struct HistoryView: View {
    @State private var viewModel = HistoryViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("A carregar...")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else if let errorMessage = viewModel.errorMessage {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                        Text(errorMessage).font(.subheadline).multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                } else if viewModel.entries.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "clock").font(.system(size: 36)).foregroundStyle(.secondary)
                        Text("Ainda não há pesquisas no histórico.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 40)
                } else {
                    List(viewModel.entries) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.city).font(.headline)
                                Text(entry.searchedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(entry.units.temperatureSymbol)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.blue.opacity(0.15), in: Capsule())
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Histórico")
            .task { await viewModel.loadHistory() }
            .refreshable { await viewModel.loadHistory() }
        }
    }
}

#Preview {
    HistoryView()
}
