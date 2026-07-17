import Foundation
import Observation

enum AuthMode: String, CaseIterable, Identifiable {
    case login = "Entrar"
    case register = "Criar conta"

    var id: String { rawValue }
}

/// Backs the combined Login/Register screen. Validates input locally before
/// hitting the network, and surfaces the backend's `message` verbatim on failure.
@MainActor
@Observable
final class AuthViewModel {
    var mode: AuthMode = .login
    var email = ""
    var password = ""
    var isLoading = false
    var errorMessage: String?

    private let authStore: AuthStore

    init(authStore: AuthStore) {
        self.authStore = authStore
    }

    var isFormValid: Bool {
        email.contains("@") && password.count >= 8
    }

    func submit() async {
        guard isFormValid else {
            errorMessage = "Introduz um email válido e uma password com pelo menos 8 caracteres."
            return
        }

        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            switch mode {
            case .login:
                try await authStore.login(email: email, password: password)
            case .register:
                try await authStore.register(email: email, password: password)
            }
        } catch let apiError as APIError {
            errorMessage = apiError.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
