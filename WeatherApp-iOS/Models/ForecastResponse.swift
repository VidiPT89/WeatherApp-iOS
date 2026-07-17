import Foundation

/// One entry of `forecast.hourly`. `time` is a zone-less local datetime
/// (`2024-01-01T00:00:00`), decoded via `BackendDateFormatters.localDateTime`
/// rather than `.iso8601` (which requires an offset and would throw).
struct HourlyForecastEntry: Decodable, Equatable, Identifiable {
    let time: Date
    let temperature: Double
    let description: String

    var id: Date { time }

    enum CodingKeys: String, CodingKey {
        case time, temperature, description
    }

    init(time: Date, temperature: Double, description: String) {
        self.time = time
        self.temperature = temperature
        self.description = description
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
    }
}

/// One entry of `forecast.daily`. `date` is a zone-less local date
/// (`2024-01-01`), decoded via `BackendDateFormatters.localDate`.
struct DailyForecastEntry: Decodable, Equatable, Identifiable {
    let date: Date
    let temperatureMax: Double
    let temperatureMin: Double
    let description: String

    var id: Date { date }

    enum CodingKeys: String, CodingKey {
        case date, temperatureMax, temperatureMin, description
    }

    init(date: Date, temperatureMax: Double, temperatureMin: Double, description: String) {
        self.date = date
        self.temperatureMax = temperatureMax
        self.temperatureMin = temperatureMin
        self.description = description
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawDate = try container.decode(String.self, forKey: .date)
        guard let parsed = BackendDateFormatters.localDate.date(from: rawDate) else {
            throw DateDecodingError.invalidLocalDate(rawDate)
        }
        date = parsed
        temperatureMax = try container.decode(Double.self, forKey: .temperatureMax)
        temperatureMin = try container.decode(Double.self, forKey: .temperatureMin)
        description = try container.decode(String.self, forKey: .description)
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
