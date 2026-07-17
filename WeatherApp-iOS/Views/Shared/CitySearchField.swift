import SwiftUI

/// A search field with a debounced autocomplete dropdown, backed by
/// `CitySearchViewModel` (which talks to `/geocoding`). Shared by Dashboard
/// and Compare. Calling `onSubmitCity` fires on both manual submit and
/// suggestion tap.
struct CitySearchField: View {
    @Bindable var searchViewModel: CitySearchViewModel
    var placeholder: String = "Procurar cidade..."
    var identifier: String = "citySearch.field"
    var onSubmitCity: (String) -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(placeholder, text: $searchViewModel.queryText)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .focused($isFocused)
                    .onSubmit {
                        submit(searchViewModel.queryText)
                    }
                    .accessibilityIdentifier(identifier)
                if searchViewModel.isSearching {
                    ProgressView().controlSize(.small)
                }
            }
            .padding(10)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))

            if isFocused && !searchViewModel.suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(searchViewModel.suggestions) { suggestion in
                        Button {
                            submit(suggestion.name)
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(suggestion.name)
                                        .foregroundStyle(.primary)
                                    Text(suggestion.country)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if suggestion.id != searchViewModel.suggestions.last?.id {
                            Divider().padding(.leading, 12)
                        }
                    }
                }
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                .padding(.top, 4)
            }
        }
    }

    private func submit(_ city: String) {
        guard !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isFocused = false
        searchViewModel.clearSuggestions()
        searchViewModel.queryText = city
        onSubmitCity(city)
    }
}
