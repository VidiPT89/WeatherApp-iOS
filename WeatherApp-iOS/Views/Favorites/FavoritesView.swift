import SwiftUI

/// Favorites list + add-by-name form. Tapping a favorite jumps to the
/// Dashboard pre-loaded with that city via `onSelectCity`.
struct FavoritesView: View {
    let onSelectCity: (String) -> Void

    @State private var viewModel = FavoritesViewModel()
    @State private var searchViewModel = CitySearchViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                addForm

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
                } else if viewModel.favorites.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "star").font(.system(size: 36)).foregroundStyle(.secondary)
                        Text("Ainda não tens cidades favoritas.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 40)
                } else {
                    List(viewModel.favorites) { favorite in
                        Button {
                            onSelectCity(favorite.city)
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(favorite.city).font(.headline)
                                    Text(favorite.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await viewModel.removeFavorite(favorite) }
                            } label: {
                                Label("Eliminar", systemImage: "trash")
                            }
                            .disabled(viewModel.removingCity == favorite.city)
                        }
                    }
                    .listStyle(.plain)
                }
                Spacer()
            }
            .navigationTitle("Favoritos")
            .task { await viewModel.loadFavorites() }
        }
    }

    private var addForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Autocomplete-only, backed by the same `/geocoding` search used
            // on the Dashboard -- picking a real suggestion (rather than
            // free-typing a name) guarantees whatever gets POSTed to
            // `/favorites` is a place the backend's weather-by-name lookup
            // can actually resolve later.
            CitySearchField(
                searchViewModel: searchViewModel,
                placeholder: "Adicionar cidade...",
                identifier: "favorites.cityField",
                onSubmitCity: { city in
                    Task {
                        await viewModel.addFavorite(city: city)
                        searchViewModel.queryText = ""
                    }
                }
            )

            if let feedback = viewModel.addFeedback {
                Text(feedback)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

#Preview {
    FavoritesView(onSelectCity: { _ in })
}
