import AuthenticationServices
import Foundation
import GoogleSignIn
import MSAL
import Observation
import UIKit

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

    /// Google's SDK needs a presenting `UIViewController` (no SwiftUI-native API for this) --
    /// the currently active window's root, same as Google's own integration guide recommends.
    private func presentingViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
    }

    func signInWithGoogle() async {
        guard let presenter = presentingViewController() else { return }

        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Não foi possível obter o token do Google."
                return
            }
            try await authStore.loginWithOAuth(provider: "google", idToken: idToken)
        } catch let apiError as APIError {
            errorMessage = apiError.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// `SignInWithAppleButton` (native, `AuthenticationServices`) drives the whole flow itself
    /// and hands back this completion -- no presenting-view-controller plumbing needed, unlike Google.
    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        errorMessage = nil

        guard case .success(let authorization) = result else {
            if case .failure(let error) = result,
               (error as? ASAuthorizationError)?.code == .canceled {
                return
            }
            if case .failure(let error) = result {
                errorMessage = error.localizedDescription
            }
            return
        }

        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            errorMessage = "Não foi possível obter o token da Apple."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await authStore.loginWithOAuth(provider: "apple", idToken: idToken)
        } catch let apiError as APIError {
            errorMessage = apiError.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signInWithMicrosoft() async {
        guard let presenter = presentingViewController() else { return }
        guard let clientId = Bundle.main.object(forInfoDictionaryKey: "MICROSOFT_CLIENT_ID") as? String,
              !clientId.isEmpty else {
            errorMessage = "Login com Microsoft não está configurado."
            return
        }

        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            // Same "common" multi-tenant authority as the Web client (see WeatherApp/
            // src/lib/social-auth.ts) -- accepts both personal and work/school Microsoft accounts.
            let authorityUrl = URL(string: "https://login.microsoftonline.com/common")!
            let authority = try MSALAADAuthority(url: authorityUrl)
            // redirectUri: nil lets MSAL compute its own default ("msauth.<bundle-id>://auth")
            // from the running app's actual bundle identifier at runtime, rather than trusting a
            // literal string here to stay in sync with it.
            let config = MSALPublicClientApplicationConfig(
                clientId: clientId,
                redirectUri: nil,
                authority: authority)
            let application = try MSALPublicClientApplication(configuration: config)

            // MSAL always adds "openid", "profile", and "offline_access" itself and rejects
            // them if the caller also specifies them ("reserved scopes" error) -- only "email"
            // needs requesting explicitly to get the email claim onto the ID token.
            let webParameters = MSALWebviewParameters(authPresentationViewController: presenter)
            let parameters = MSALInteractiveTokenParameters(
                scopes: ["email"], webviewParameters: webParameters)

            let result: MSALResult = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<MSALResult, Error>) in
                application.acquireToken(with: parameters) { tokenResult, error in
                    if let tokenResult {
                        continuation.resume(returning: tokenResult)
                    } else {
                        continuation.resume(throwing: error ?? APIError.invalidResponse)
                    }
                }
            }

            guard let idToken = result.idToken else {
                errorMessage = "Não foi possível obter o token da Microsoft."
                return
            }
            try await authStore.loginWithOAuth(provider: "microsoft", idToken: idToken)
        } catch let apiError as APIError {
            errorMessage = apiError.errorDescription
        } catch let nsError as NSError where nsError.domain == MSALErrorDomain
            && nsError.code == MSALError.userCanceled.rawValue {
            // User dismissed the Microsoft login sheet -- not a failure worth surfacing.
        } catch {
            // MSAL's generic MSALErrorInternal (-50000) carries no localizedDescription of its
            // own, so NSError falls back to an unhelpful boilerplate string -- surface whatever
            // MSAL actually put in userInfo (e.g. MSALInternalErrorCodeKey/NSUnderlyingErrorKey)
            // instead, since that's the only way to tell what really failed.
            let nsError = error as NSError
            var detail = nsError.localizedDescription
            // MSAL stores its real diagnostic text under this key, not NSLocalizedDescriptionKey
            // -- that's why .localizedDescription alone is always the generic Cocoa boilerplate.
            if let msalDescription = nsError.userInfo["MSALErrorDescriptionKey"] as? String {
                detail += " | MSAL: \(msalDescription)"
            }
            if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                detail += " | underlying: \(underlying.domain) #\(underlying.code): \(underlying.localizedDescription)"
            }
            if let internalCode = nsError.userInfo["MSALInternalErrorCodeKey"] {
                detail += " | internalCode: \(internalCode)"
            }
            errorMessage = detail
        }
    }
}
