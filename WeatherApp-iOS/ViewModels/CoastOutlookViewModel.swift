import Foundation
import Observation

/// Backs one spot's detail screen: the four-day outlook and which day is being looked at.
@MainActor
@Observable
final class CoastOutlookViewModel {
    let spot: CoastSpot
    private(set) var outlook: CoastOutlookResponse?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    var selectedDayIndex = 0

    private let apiClient: APIClient
    private var loadGeneration = 0

    init(spot: CoastSpot, apiClient: APIClient = .shared) {
        self.spot = spot
        self.apiClient = apiClient
    }

    var selectedDay: CoastDay? {
        guard let days = outlook?.days, days.indices.contains(selectedDayIndex) else { return nil }
        return days[selectedDayIndex]
    }

    func load(units: Units) async {
        loadGeneration += 1
        let generation = loadGeneration
        isLoading = outlook == nil
        errorMessage = nil
        defer { if generation == loadGeneration { isLoading = false } }

        do {
            let result = try await fetchWithRetry(units: units)
            guard generation == loadGeneration else { return }
            outlook = result
            if !result.days.indices.contains(selectedDayIndex) {
                selectedDayIndex = 0
            }
        } catch {
            guard generation == loadGeneration, !Task.isCancelled else { return }
            errorMessage = LocalizedStrings.string(
                "Não foi possível carregar as condições desta praia. Tenta outra vez dentro de momentos.",
                locale: AppLocale.current.locale)
        }
    }

    private func fetchWithRetry(units: Units) async throws -> CoastOutlookResponse {
        do {
            return try await apiClient.fetchCoastOutlook(spotId: spot.id, units: units)
        } catch {
            try Task.checkCancellation()
            return try await apiClient.fetchCoastOutlook(spotId: spot.id, units: units)
        }
    }
}
