import Foundation

/// Actor wrapping `URLSession` for every backend call. Attaches the Bearer
/// token to authenticated requests and decodes the backend's standard error
/// body on non-2xx responses, throwing a typed `APIError` that carries the
/// human-readable `message`.
actor APIClient {
    static let shared = APIClient()

    /// Sourced from the `API_BASE_URL` Info.plist key (itself driven by the `WEATHER_API_BASE_URL`
    /// build setting in project.yml) so pointing a build at a different backend -- staging, a
    /// local server for QA -- is a build-setting change, not a source edit and a re-release. The
    /// literal here is only a fallback for contexts with no app bundle Info.plist (e.g. this
    /// actor being touched from a plain unit test target), not the value real app runs use.
    static let baseURL: URL = {
        guard let configured = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
              let url = URL(string: configured), !configured.isEmpty else {
            return URL(string: "https://weatherapi-4r5x.onrender.com")!
        }
        return url
    }()

    private let session: URLSession
    private var authToken: String?
    private var refreshToken: String?
    private var onTokensRefreshed: (@Sendable (AuthResponse) -> Void)?
    private var onRefreshFailed: (@Sendable () -> Void)?
    private var inFlightRefresh: Task<Bool, Never>?

    /// The backend's free-tier host spins down after inactivity and can take up to ~3 minutes
    /// to cold-boot (Flyway + Hibernate init) on the next request -- `URLSession.shared`'s
    /// default 60s timeout fires well before that finishes, which without this override made
    /// the very first request after any idle period fail (silently, by design elsewhere) even
    /// though the backend was healthy and would have answered a few seconds later.
    private static let defaultSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 180
        return URLSession(configuration: configuration)
    }()

    init(session: URLSession = APIClient.defaultSession) {
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

    /// Registers a callback fired when an in-band refresh attempt (triggered by `perform`
    /// hitting a 401 UNAUTHENTICATED) *definitively fails* -- i.e. the refresh token itself was
    /// rejected, not just a transient network hiccup on the refresh call. `AuthStore` uses this
    /// to fall back to its own `logout()` so the app drops back to the login screen instead of
    /// being stuck "authenticated" with a dead token pair forever. Fired at most once per failed
    /// refresh regardless of how many concurrent callers were waiting on it, since they all share
    /// the single in-flight `Task`.
    func setOnRefreshFailed(_ handler: @escaping @Sendable () -> Void) {
        onRefreshFailed = handler
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

    /// Exchanges a native ID token (already obtained on-device from the provider's own SDK -- see
    /// `AuthViewModel.signInWithGoogle`) for the same `AuthResponse` shape `login`/`register`
    /// return. `provider` is lowercase, e.g. "google".
    func loginWithOAuth(provider: String, idToken: String) async throws -> AuthResponse {
        try await send(
            path: "/api/v1/auth/oauth/\(provider)",
            method: "POST",
            body: OAuthRequest(idToken: idToken),
            requiresAuth: false
        )
    }

    // MARK: - Weather endpoints

    func fetchWeather(city: String, units: Units?) async throws -> WeatherResponse {
        try await send(
            path: "/api/v1/weather", method: "GET", queryItems: Self.cityQuery(city, units), requiresAuth: false)
    }

    /// Weather for the caller's GPS coordinates, reverse-geocoded server-side to a city.
    func fetchWeatherNearby(latitude: Double, longitude: Double, units: Units?) async throws -> WeatherResponse {
        var items = [URLQueryItem(name: "lat", value: String(latitude)), URLQueryItem(name: "lon", value: String(longitude))]
        if let units {
            items.append(URLQueryItem(name: "units", value: units.rawValue))
        }
        return try await send(path: "/api/v1/weather/nearby", method: "GET", queryItems: items, requiresAuth: false)
    }

    func fetchForecast(city: String, units: Units?) async throws -> ForecastResponse {
        try await send(
            path: "/api/v1/weather/forecast", method: "GET", queryItems: Self.cityQuery(city, units),
            requiresAuth: false)
    }

    /// Water temperature + swell (wave height/direction/period) for a city.
    /// All four data fields are `nil` for inland/non-coastal cities — that's
    /// a normal 200 response, not an error.
    func fetchMarine(city: String, units: Units?) async throws -> MarineResponse {
        try await send(
            path: "/api/v1/weather/marine", method: "GET", queryItems: Self.cityQuery(city, units),
            requiresAuth: false)
    }

    /// Derived indicators (moon phase, UV risk, outdoor-activity score, fishing
    /// conditions). `fishingConditionLabel` is `nil` for inland/non-coastal cities.
    func fetchInsights(city: String, units: Units?) async throws -> WeatherInsightsResponse {
        try await send(
            path: "/api/v1/weather/insights", method: "GET", queryItems: Self.cityQuery(city, units),
            requiresAuth: false)
    }

    func fetchHistory() async throws -> [HistoryEntry] {
        try await send(path: "/api/v1/weather/history", method: "GET")
    }

    /// Deletes a single history entry belonging to the caller. Throws an `APIError.server`
    /// with a 404 status if `id` doesn't exist or belongs to another user.
    func deleteHistoryEntry(id: Int) async throws {
        let _: EmptyResponse = try await send(path: "/api/v1/weather/history/\(id)", method: "DELETE")
    }

    /// Clears the caller's entire search history. Always `204`, even if the history was
    /// already empty.
    func clearHistory() async throws {
        let _: EmptyResponse = try await send(path: "/api/v1/weather/history", method: "DELETE")
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

    /// Removes `city` (case-insensitive on the backend) from the caller's favorites. The
    /// backend takes `city` as a query parameter rather than a path segment, and returns 404
    /// (surfaced as a thrown `APIError`) if it isn't currently a favorite.
    func removeFavorite(city: String) async throws {
        let _: EmptyResponse = try await send(
            path: "/api/v1/weather/favorites",
            method: "DELETE",
            queryItems: [URLQueryItem(name: "city", value: city)]
        )
    }

    // MARK: - Geocoding

    func searchCities(query: String, limit: Int = 5) async throws -> GeocodingResponse {
        let queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        return try await send(path: "/api/v1/geocoding", method: "GET", queryItems: queryItems, requiresAuth: false)
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

    /// The caller's own account, including `role` -- nothing else exposes that client-side.
    func fetchMe() async throws -> UserAccount {
        try await send(path: "/api/v1/user/me", method: "GET")
    }

    // MARK: - Admin (server rejects these with 403 unless the caller's role is admin)

    func fetchAdminUsers() async throws -> [UserAccount] {
        try await send(path: "/api/v1/admin/users", method: "GET")
    }

    func deleteAdminUser(id: Int) async throws {
        let _: EmptyResponse = try await send(path: "/api/v1/admin/users/\(id)", method: "DELETE")
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
                await self.notifyRefreshFailed()
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

    private func notifyRefreshFailed() {
        onRefreshFailed?()
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
        } else if let authToken {
            // Weather lookup works anonymously, but a signed-in caller still gets its
            // preferred units applied and searches recorded to history server-side --
            // both keyed off this same Authorization header when present.
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
