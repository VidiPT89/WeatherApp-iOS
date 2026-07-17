import SwiftUI

/// Main screen: city search with autocomplete, current-conditions card
/// (with cache badge + fallback banner), forecast chart, and a unit toggle.
struct DashboardView: View {
    @Binding var prefillCity: String?

    @State private var viewModel = DashboardViewModel()
    @State private var searchViewModel = CitySearchViewModel()
    @State private var didLoadInitialPreferences = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    CitySearchField(searchViewModel: searchViewModel, identifier: "dashboard.citySearch", onSubmitCity: search)

                    content
                }
                .padding()
            }
            .navigationTitle("WeatherApp")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    unitsToggle
                }
            }
        }
        .task {
            if !didLoadInitialPreferences {
                didLoadInitialPreferences = true
                await viewModel.loadInitialPreferences()
            }
        }
        .onChange(of: prefillCity) { _, newValue in
            guard let city = newValue else { return }
            searchViewModel.queryText = city
            search(city)
            prefillCity = nil
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView("A carregar...")
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
        } else if let errorMessage = viewModel.errorMessage {
            ErrorStateView(message: errorMessage)
        } else if let weather = viewModel.weather, let forecast = viewModel.forecast {
            VStack(alignment: .leading, spacing: 16) {
                if weather.isFallbackProvider {
                    FallbackBannerView(provider: weather.provider)
                }
                WeatherCardView(weather: weather)
                ForecastChartView(forecast: forecast, range: $viewModel.forecastRange)
            }
        } else if !viewModel.hasSearchedOnce {
            EmptyStateView()
        }
    }

    private var unitsToggle: some View {
        Picker("Unidades", selection: Binding(
            get: { viewModel.units },
            set: { newUnits in Task { await viewModel.changeUnits(to: newUnits) } }
        )) {
            ForEach(Units.allCases) { units in
                Text(units.temperatureSymbol).tag(units)
            }
        }
        .pickerStyle(.segmented)
        .fixedSize()
    }

    private func search(_ city: String) {
        Task { await viewModel.loadWeather(for: city) }
    }
}

private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Procura uma cidade para veres o tempo atual e a previsão.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}

private struct ErrorStateView: View {
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.red)
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

#Preview {
    DashboardView(prefillCity: .constant(nil))
}
