import Foundation

/// The JSON body shape shared by every non-2xx response from the backend.
struct APIErrorResponse: Decodable, Equatable {
    let timestamp: String
    let status: Int
    let error: String
    let message: String
    let path: String
}

/// Typed error surfaced by `APIClient`, carrying the backend's human-readable
/// `message` so views can show it directly.
enum APIError: Error, LocalizedError, Equatable {
    /// A non-2xx HTTP response the backend described with its standard error body.
    case server(status: Int, message: String)
    /// A non-2xx HTTP response whose body wasn't the standard error shape.
    case unexpectedResponse(status: Int)
    /// The response body couldn't be decoded into the expected model.
    case decoding(String)
    /// Network transport failure (offline, timeout, connection refused, etc).
    case transport(String)
    /// No JWT is available to attach to an authenticated request.
    case unauthenticated

    var errorDescription: String? {
        switch self {
        case .server(_, let message):
            return message
        case .unexpectedResponse(let status):
            return "O servidor respondeu com um erro inesperado (\(status))."
        case .decoding(let details):
            return "Não foi possível interpretar a resposta do servidor (\(details))."
        case .transport(let details):
            return "Falha de rede: \(details)"
        case .unauthenticated:
            return "Sessão expirada. Por favor, inicia sessão novamente."
        }
    }
}
