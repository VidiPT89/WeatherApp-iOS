import Foundation

/// One entry of `forecast.hourly` (48 entries). `time` is a zone-less local
/// datetime (`2024-01-01T00:00:00`), decoded via
/// `BackendDateFormatters.localDateTime` rather than `.iso8601` (which
/// requires an offset and would throw).
struct HourlyForecastEntry: Decodable, Equatable, Identifiable {
    let time: Date
    let temperature: Double
    let description: String
    let precipitationProbability: Int

    var id: Date { time }

    enum CodingKeys: String, CodingKey {
        case time, temperature, description, precipitationProbability
    }

    init(time: Date, temperature: Double, description: String, precipitationProbability: Int) {
        self.time = time
        self.temperature = temperature
        self.description = description
        self.precipitationProbability = precipitationProbability
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawTime = try container.decode(String.self, forKey: .time)
        guard let parsed = BackendDateFormatters.localDateTime.date(from: rawTime) else {
            throw DateDecodingError.invalidLocalDateTime(rawTime)
        }
        time = parsed
        temperature = try container.decode(Double.self, forKey: .temperature)
        description = try container.decode(String.self, forKey: .description)
        precipitationProbability = try container.decode(Int.self, forKey: .precipitationProbability)
    }
}

/// One entry of `forecast.daily` (16 entries). `date` is a zone-less local
/// date (`2024-01-01`), decoded via `BackendDateFormatters.localDate`.
/// `sunrise`/`sunset` are local ISO datetimes, decoded the same way as
/// `hourly[].time`.
struct DailyForecastEntry: Decodable, Equatable, Identifiable {
    let date: Date
    let temperatureMax: Double
    let temperatureMin: Double
    let description: String
    let sunrise: Date
    let sunset: Date
    let uvIndexMax: Double
    let precipitationProbabilityMax: Int

    var id: Date { date }

    enum CodingKeys: String, CodingKey {
        case date, temperatureMax, temperatureMin, description
        case sunrise, sunset, uvIndexMax, precipitationProbabilityMax
    }

    init(
        date: Date,
        temperatureMax: Double,
        temperatureMin: Double,
        description: String,
        sunrise: Date,
        sunset: Date,
        uvIndexMax: Double,
        precipitationProbabilityMax: Int
    ) {
        self.date = date
        self.temperatureMax = temperatureMax
        self.temperatureMin = temperatureMin
        self.description = description
        self.sunrise = sunrise
        self.sunset = sunset
        self.uvIndexMax = uvIndexMax
        self.precipitationProbabilityMax = precipitationProbabilityMax
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawDate = try container.decode(String.self, forKey: .date)
        guard let parsedDate = BackendDateFormatters.localDate.date(from: rawDate) else {
            throw DateDecodingError.invalidLocalDate(rawDate)
        }
        date = parsedDate

        temperatureMax = try container.decode(Double.self, forKey: .temperatureMax)
        temperatureMin = try container.decode(Double.self, forKey: .temperatureMin)
        description = try container.decode(String.self, forKey: .description)

        let rawSunrise = try container.decode(String.self, forKey: .sunrise)
        guard let parsedSunrise = BackendDateFormatters.localDateTime.date(from: rawSunrise) else {
            throw DateDecodingError.invalidLocalDateTime(rawSunrise)
        }
        sunrise = parsedSunrise

        let rawSunset = try container.decode(String.self, forKey: .sunset)
        guard let parsedSunset = BackendDateFormatters.localDateTime.date(from: rawSunset) else {
            throw DateDecodingError.invalidLocalDateTime(rawSunset)
        }
        sunset = parsedSunset

        uvIndexMax = try container.decode(Double.self, forKey: .uvIndexMax)
        precipitationProbabilityMax = try container.decode(Int.self, forKey: .precipitationProbabilityMax)
    }
}

/// `GET /api/v1/weather/forecast` response.
struct ForecastResponse: Decodable, Equatable {
    let city: String
    let country: String
    let units: Units
    let provider: String
    let fromCache: Bool
    let hourly: [HourlyForecastEntry]
    let daily: [DailyForecastEntry]
}
