import Foundation

/// Actor wrapping `URLSession` for every backend call. Attaches the Bearer
/// token to authenticated requests and decodes the backend's standard error
/// body on non-2xx responses, throwing a typed `APIError` that carries the
/// human-readable `message`.
actor APIClient {
    static let shared = APIClient()

    static let baseURL = URL(string: "https://weather-api-production-68ff.up.railway.app")!

    private let session: URLSession
    private var authToken: String?
    private var refreshToken: String?
    private var onTokensRefreshed: (@Sendable (AuthResponse) -> Void)?
    private var inFlightRefresh: Task<Bool, Never>?

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Updates the tokens attached to future requests. Called by `AuthStore` on
    /// login/register/logout (with `nil` for both on logout).
    func setTokens(access: String?, refresh: String?) {
        authToken = access
        refreshToken = refresh
    }

    /// Registers a callback fired whenever `perform` silently refreshes the
    /// access token on the client's behalf, so `AuthStore` can persist the new
    /// pair to the Keychain. Login/register/logout persistence is handled by
    /// `AuthStore` directly via `setTokens` — this is only for the in-band case.
    func setOnTokensRefreshed(_ handler: @escaping @Sendable (AuthResponse) -> Void) {
        onTokensRefreshed = handler
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

    /// Best-effort server-side revocation. Callers should clear local state
    /// regardless of whether this succeeds.
    func logout() async {
        guard let refreshToken else { return }
        _ = try? await send(
            path: "/api/v1/auth/logout",
            method: "POST",
            body: RefreshRequest(refreshToken: refreshToken),
            requiresAuth: false
        ) as EmptyResponse
    }

    // MARK: - Weather endpoints

    func fetchWeather(city: String, units: Units?) async throws -> WeatherResponse {
        try await send(path: "/api/v1/weather", method: "GET", queryItems: Self.cityQuery(city, units))
    }

    func fetchForecast(city: String, units: Units?) async throws -> ForecastResponse {
        try await send(path: "/api/v1/weather/forecast", method: "GET", queryItems: Self.cityQuery(city, units))
    }

    /// Water temperature + swell (wave height/direction/period) for a city.
    /// All four data fields are `nil` for inland/non-coastal cities — that's
    /// a normal 200 response, not an error.
    func fetchMarine(city: String, units: Units?) async throws -> MarineResponse {
        try await send(path: "/api/v1/weather/marine", method: "GET", queryItems: Self.cityQuery(city, units))
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
        requiresAuth: Bool = true,
        allowRefresh: Bool = true
    ) async throws -> Response {
        let request = try makeRequest(path: path, method: method, queryItems: queryItems, bodyData: nil, requiresAuth: requiresAuth)
        return try await perform(request, allowRefresh: allowRefresh)
    }

    /// POST-style call with an encodable request body.
    private func send<Body: Encodable, Response: Decodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        body: Body,
        requiresAuth: Bool = true,
        allowRefresh: Bool = true
    ) async throws -> Response {
        let bodyData: Data
        do {
            bodyData = try Self.encoder.encode(body)
        } catch {
            throw APIError.requestEncodingFailed(error.localizedDescription)
        }
        let request = try makeRequest(path: path, method: method, queryItems: queryItems, bodyData: bodyData, requiresAuth: requiresAuth)
        return try await perform(request, allowRefresh: allowRefresh)
    }

    /// `allowRefresh` is `false` only for the retry itself and for the refresh
    /// call's own request — both must never trigger a second refresh attempt.
    private func perform<Response: Decodable>(_ request: URLRequest, allowRefresh: Bool = true) async throws -> Response {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let error = Self.decodeError(status: httpResponse.statusCode, data: data)
            if allowRefresh, case .server(401, _, let errorCode) = error, errorCode == "UNAUTHENTICATED",
               await refreshAccessToken() {
                var retryRequest = request
                retryRequest.setValue("Bearer \(authToken ?? "")", forHTTPHeaderField: "Authorization")
                return try await perform(retryRequest, allowRefresh: false)
            }
            throw error
        }

        if data.isEmpty, let empty = EmptyResponse() as? Response {
            return empty
        }

        do {
            return try Self.decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }

    /// Exchanges the stored refresh token for a new access+refresh pair.
    /// Concurrent callers (several requests hitting a 401 at once) share a
    /// single in-flight attempt instead of each firing their own network call.
    private func refreshAccessToken() async -> Bool {
        if let inFlightRefresh {
            return await inFlightRefresh.value
        }
        guard let refreshToken else { return false }

        let task = Task<Bool, Never> { [weak self] in
            guard let self else { return false }
            do {
                let response: AuthResponse = try await self.send(
                    path: "/api/v1/auth/refresh",
                    method: "POST",
                    body: RefreshRequest(refreshToken: refreshToken),
                    requiresAuth: false,
                    allowRefresh: false
                )
                await self.applyRefreshed(response)
                return true
            } catch {
                await self.setTokens(access: nil, refresh: nil)
                return false
            }
        }
        inFlightRefresh = task
        let result = await task.value
        inFlightRefresh = nil
        return result
    }

    private func applyRefreshed(_ response: AuthResponse) {
        authToken = response.token
        refreshToken = response.refreshToken
        onTokensRefreshed?(response)
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
            throw APIError.invalidURL
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
            return .server(status: status, message: errorBody.message, errorCode: errorBody.errorCode)
        }
        return .unexpectedResponse(status: status)
    }

    private static let decoder = JSONDecoder()
    private static let encoder = JSONEncoder()
}

/// Placeholder result type for endpoints that respond `204 No Content`.
private struct EmptyResponse: Decodable {}
