import Foundation

/// `GET /api/v1/weather` response.
struct WeatherResponse: Decodable, Equatable {
    let city: String
    let country: String
    let temperature: Double
    let feelsLike: Double
    let humidity: Int
    let windSpeed: Double
    let description: String
    let units: Units
    let provider: String
    let observedAt: Date
    let fromCache: Bool

    /// The backend's primary provider. Any other value means the request
    /// fell back to a secondary provider — the fallback event this app
    /// exists to surface.
    static let primaryProvider = "open-meteo"

    var isFallbackProvider: Bool {
        provider != Self.primaryProvider
    }

    enum CodingKeys: String, CodingKey {
        case city, country, temperature, feelsLike, humidity, windSpeed
        case description, units, provider, observedAt, fromCache
    }

    init(
        city: String,
        country: String,
        temperature: Double,
        feelsLike: Double,
        humidity: Int,
        windSpeed: Double,
        description: String,
        units: Units,
        provider: String,
        observedAt: Date,
        fromCache: Bool
    ) {
        self.city = city
        self.country = country
        self.temperature = temperature
        self.feelsLike = feelsLike
        self.humidity = humidity
        self.windSpeed = windSpeed
        self.description = description
        self.units = units
        self.provider = provider
        self.observedAt = observedAt
        self.fromCache = fromCache
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        city = try container.decode(String.self, forKey: .city)
        country = try container.decode(String.self, forKey: .country)
        temperature = try container.decode(Double.self, forKey: .temperature)
        feelsLike = try container.decode(Double.self, forKey: .feelsLike)
        humidity = try container.decode(Int.self, forKey: .humidity)
        windSpeed = try container.decode(Double.self, forKey: .windSpeed)
        description = try container.decode(String.self, forKey: .description)
        units = try container.decode(Units.self, forKey: .units)
        provider = try container.decode(String.self, forKey: .provider)
        fromCache = try container.decode(Bool.self, forKey: .fromCache)

        let rawObservedAt = try container.decode(String.self, forKey: .observedAt)
        guard let parsed = BackendDateFormatters.parseInstant(rawObservedAt) else {
            throw DateDecodingError.invalidInstant(rawObservedAt)
        }
        observedAt = parsed
    }
}
