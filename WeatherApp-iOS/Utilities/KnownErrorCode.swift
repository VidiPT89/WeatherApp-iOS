import Foundation

/// Mirrors the backend's `ErrorCode` enum (`errorCode` field on every non-2xx
/// response body). Client picks a localized string keyed on this stable,
/// language-agnostic identifier instead of showing the raw `message`, which
/// for validation failures is dynamic/untranslatable (field name + Bean
/// Validation's own English text).
enum KnownErrorCode: String {
    case cityNotFound = "CITY_NOT_FOUND"
    case providerUnavailable = "PROVIDER_UNAVAILABLE"
    case providerQuotaExceeded = "PROVIDER_QUOTA_EXCEEDED"
    case validationFailed = "VALIDATION_FAILED"
    case emailAlreadyRegistered = "EMAIL_ALREADY_REGISTERED"
    case invalidCredentials = "INVALID_CREDENTIALS"
    case favoriteAlreadyExists = "FAVORITE_ALREADY_EXISTS"
    case unauthenticated = "UNAUTHENTICATED"
    case accessDenied = "ACCESS_DENIED"
    case rateLimitExceeded = "RATE_LIMIT_EXCEEDED"
    case internalError = "INTERNAL_ERROR"

    func localizedMessage(locale: Locale) -> String {
        switch self {
        case .cityNotFound:
            return LocalizedStrings.string("Não encontrámos essa cidade.", locale: locale)
        case .providerUnavailable:
            return LocalizedStrings.string("O provider de meteorologia está indisponível. Tenta novamente mais tarde.", locale: locale)
        case .providerQuotaExceeded:
            return LocalizedStrings.string("O limite do provider foi atingido. Tenta novamente mais tarde.", locale: locale)
        case .validationFailed:
            return LocalizedStrings.string("Verifica os dados introduzidos.", locale: locale)
        case .emailAlreadyRegistered:
            return LocalizedStrings.string("Já existe uma conta com este email.", locale: locale)
        case .invalidCredentials:
            return LocalizedStrings.string("Email ou palavra-passe incorretos.", locale: locale)
        case .favoriteAlreadyExists:
            return LocalizedStrings.string("Esta cidade já está nos teus favoritos.", locale: locale)
        case .unauthenticated:
            return LocalizedStrings.string("A tua sessão expirou. Entra novamente.", locale: locale)
        case .accessDenied:
            return LocalizedStrings.string("Não tens permissão para aceder a este recurso.", locale: locale)
        case .rateLimitExceeded:
            return LocalizedStrings.string("Demasiados pedidos. Aguarda um momento e tenta novamente.", locale: locale)
        case .internalError:
            return LocalizedStrings.string("Ocorreu um erro inesperado.", locale: locale)
        }
    }
}
