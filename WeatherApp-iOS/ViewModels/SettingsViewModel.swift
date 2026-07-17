import Foundation
import Observation

/// Backs the Settings screen: shows/updates the saved unit preference.
@MainActor
@Observable
final class SettingsViewModel {
    private(set) var units: Units = .metric
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var saveConfirmation: String?

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func loadPreferences() async {
        isLoading = true
        errorMessage = nil
        do {
            let preferences = try await apiClient.fetchPreferences()
            units = preferences.units
        } catch let apiError as APIError {
            errorMessage = apiError.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func updateUnits(to newUnits: Units) async {
        guard newUnits != units else { return }
        let previousUnits = units
        units = newUnits
        saveConfirmation = nil
        errorMessage = nil

        do {
            let preferences = try await apiClient.updatePreferences(units: newUnits)
            units = preferences.units
            saveConfirmation = "Preferência guardada."
        } catch let apiError as APIError {
            units = previousUnits
            errorMessage = apiError.errorDescription
        } catch {
            units = previousUnits
            errorMessage = error.localizedDescription
        }
    }
}
