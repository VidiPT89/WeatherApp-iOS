import SwiftUI

/// Side-by-side "compare all providers for the same city" screen.
struct CompareView: View {
    @State private var viewModel = CompareViewModel()
    @State private var searchViewModel = CitySearchViewModel()
    @State private var units: Units = .metric

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    CitySearchField(
                        searchViewModel: searchViewModel,
                        placeholder: "Comparar cidade...",
                        identifier: "compare.citySearch",
                        onSubmitCity: { city in
                            Task { await viewModel.compare(city: city, units: units) }
                        }
                    )

                    content
                }
                .padding()
            }
            .navigationTitle("Comparar")
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView("A comparar...")
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
        } else if let errorMessage = viewModel.errorMessage {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                Text(errorMessage).font(.subheadline).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
        } else if let result = viewModel.result {
            VStack(alignment: .leading, spacing: 12) {
                Text(result.city)
                    .font(.title2.bold())

                ForEach(result.results) { providerResult in
                    ProviderResultCard(result: providerResult)
                }

                if let average = result.averageTemperature {
                    HStack {
                        Image(systemName: "equal.circle.fill")
                        Text("Média entre providers com sucesso: \(String(format: "%.1f", average))\(units.temperatureSymbol)")
                            .font(.subheadline.weight(.medium))
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        } else if !viewModel.hasSearchedOnce {
            VStack(spacing: 12) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("Procura uma cidade para comparar todos os providers de meteorologia.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
        }
    }
}

#Preview {
    CompareView()
}
