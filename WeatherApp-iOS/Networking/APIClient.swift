import Foundation

/// Actor wrapping `URLSession` for every backend call. Attaches the Bearer
/// token to authenticated requests and decodes the backend's standard error
/// body on non-2xx responses, throwing a typed `APIError` that carries the
/// human-readable `message`.
actor APIClient {
    static let shared = APIClient()

    static let baseURL = URL(string: "http://localhost:8080")!

    private let session: URLSession
    private var authToken: String?

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Updates the token attached to future authenticated requests. Called by
    /// `AuthStore` on login/logout.
    func setToken(_ token: String?) {
        authToken = token
    }

    // MARK: - Auth endpoints (no token required)

    func register(email: String, password: String) async throws -> AuthResponse {
        try await send(
            path: "/api/v1/auth/register",
            method: "POST",
            body: AuthRequest(email: email, password: password),
            requiresAuth: false
        )
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        try await send(
            path: "/api/v1/auth/login",
            method: "POST",
            body: AuthRequest(email: email, password: password),
            requiresAuth: false
        )
    }

    // MARK: - Weather endpoints

    func fetchWeather(city: String, units: Units?) async throws -> WeatherResponse {
        try await send(path: "/api/v1/weather", method: "GET", queryItems: Self.cityQuery(city, units))
    }

    func fetchForecast(city: String, units: Units?) async throws -> ForecastResponse {
        try await send(path: "/api/v1/weather/forecast", method: "GET", queryItems: Self.cityQuery(city, units))
    }

    func compareProviders(city: String, units: Units?) async throws -> CompareResponse {
        try await send(path: "/api/v1/weather/compare", method: "GET", queryItems: Self.cityQuery(city, units))
    }

    func fetchHistory() async throws -> [HistoryEntry] {
        try await send(path: "/api/v1/weather/history", method: "GET")
    }

    func fetchFavorites() async throws -> [FavoriteCity] {
        try await send(path: "/api/v1/weather/favorites", method: "GET")
    }

    func addFavorite(city: String) async throws -> FavoriteCity {
        try await send(
            path: "/api/v1/weather/favorites",
            method: "POST",
            body: AddFavoriteRequest(city: city)
        )
    }

    // MARK: - Geocoding

    func searchCities(query: String, limit: Int = 5) async throws -> GeocodingResponse {
        let queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        return try await send(path: "/api/v1/geocoding", method: "GET", queryItems: queryItems)
    }

    // MARK: - Preferences

    func fetchPreferences() async throws -> UserPreferences {
        try await send(path: "/api/v1/user/preferences", method: "GET")
    }

    func updatePreferences(units: Units) async throws -> UserPreferences {
        try await send(
            path: "/api/v1/user/preferences",
            method: "POST",
            body: UserPreferences(units: units)
        )
    }

    // MARK: - Core request plumbing

    private static func cityQuery(_ city: String, _ units: Units?) -> [URLQueryItem] {
        var items = [URLQueryItem(name: "city", value: city)]
        if let units {
            items.append(URLQueryItem(name: "units", value: units.rawValue))
        }
        return items
    }

    /// GET-style call with no request body.
    private func send<Response: Decodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        requiresAuth: Bool = true
    ) async throws -> Response {
        let request = try makeRequest(path: path, method: method, queryItems: queryItems, bodyData: nil, requiresAuth: requiresAuth)
        return try await perform(request)
    }

    /// POST-style call with an encodable request body.
    private func send<Body: Encodable, Response: Decodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        body: Body,
        requiresAuth: Bool = true
    ) async throws -> Response {
        let bodyData: Data
        do {
            bodyData = try Self.encoder.encode(body)
        } catch {
            throw APIError.decoding("Falha ao construir o pedido: \(error.localizedDescription)")
        }
        let request = try makeRequest(path: path, method: method, queryItems: queryItems, bodyData: bodyData, requiresAuth: requiresAuth)
        return try await perform(request)
    }

    private func perform<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.transport("Resposta inválida do servidor.")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw Self.decodeError(status: httpResponse.statusCode, data: data)
        }

        do {
            return try Self.decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }

    private func makeRequest(
        path: String,
        method: String,
        queryItems: [URLQueryItem],
        bodyData: Data?,
        requiresAuth: Bool
    ) throws -> URLRequest {
        var components = URLComponents(url: Self.baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }
        guard let url = components?.url else {
            throw APIError.transport("URL inválido.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method

        if requiresAuth {
            guard let authToken else {
                throw APIError.unauthenticated
            }
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }

        if let bodyData {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = bodyData
        }

        return request
    }

    private static func decodeError(status: Int, data: Data) -> APIError {
        if let errorBody = try? decoder.decode(APIErrorResponse.self, from: data) {
            return .server(status: status, message: errorBody.message)
        }
        return .unexpectedResponse(status: status)
    }

    private static let decoder = JSONDecoder()
    private static let encoder = JSONEncoder()
}
