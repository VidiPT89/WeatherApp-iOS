import Foundation

/// The JSON body shape shared by every non-2xx response from the backend.
/// `errorCode` is a stable, language-agnostic identifier (see
/// `KnownErrorCode`) clients should prefer over `message` for user-facing
/// copy, since `message` is dynamic/English-only for some error kinds
/// (e.g. validation errors).
struct APIErrorResponse: Decodable, Equatable {
    let timestamp: String
    let status: Int
    let error: String
    let message: String
    let path: String
    let errorCode: String?
}

/// Typed error surfaced by `APIClient`. `errorDescription` resolves against
/// `AppLocale.current` for convenience (e.g. generic `catch { error.localizedDescription }`
/// sites), but call sites that already know the active locale should prefer
/// `localizedDescription(locale:)` directly.
enum APIError: Error, LocalizedError, Equatable {
    /// A non-2xx HTTP response the backend described with its standard error body.
    /// `errorCode` is `nil` when the backend didn't send one (older responses)
    /// or it isn't one of `KnownErrorCode` — `message` is used verbatim in that case.
    case server(status: Int, message: String, errorCode: String?)
    /// A non-2xx HTTP response whose body wasn't the standard error shape.
    case unexpectedResponse(status: Int)
    /// The response body couldn't be decoded into the expected model.
    case decoding(String)
    /// The outgoing request body couldn't be encoded.
    case requestEncodingFailed(String)
    /// The response wasn't a valid HTTP response at all.
    case invalidResponse
    /// The request URL couldn't be constructed.
    case invalidURL
    /// Network transport failure (offline, timeout, connection refused, etc).
    case transport(String)
    /// No JWT is available to attach to an authenticated request.
    case unauthenticated

    var errorDescription: String? {
        localizedDescription(locale: AppLocale.current.locale)
    }

    /// Locale-aware message. Prefer this over `errorDescription` from any
    /// call site that has (or can read) the user's `AppLocale` preference.
    func localizedDescription(locale: Locale) -> String {
        switch self {
        case .server(_, let message, let errorCode):
            if let errorCode, let known = KnownErrorCode(rawValue: errorCode) {
                return known.localizedMessage(locale: locale)
            }
            return message
        case .unexpectedResponse(let status):
            return LocalizedStrings.string("O servidor respondeu com um erro inesperado (\(status)).", locale: locale)
        case .decoding(let details):
            return LocalizedStrings.string("Não foi possível interpretar a resposta do servidor (\(details)).", locale: locale)
        case .requestEncodingFailed(let details):
            return LocalizedStrings.string("Falha ao construir o pedido (\(details)).", locale: locale)
        case .invalidResponse:
            return LocalizedStrings.string("Resposta inválida do servidor.", locale: locale)
        case .invalidURL:
            return LocalizedStrings.string("URL do pedido inválido.", locale: locale)
        case .transport(let details):
            return LocalizedStrings.string("Falha de rede: \(details)", locale: locale)
        case .unauthenticated:
            return LocalizedStrings.string("Sessão expirada. Por favor, inicia sessão novamente.", locale: locale)
        }
    }
}
