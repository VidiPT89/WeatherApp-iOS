import Foundation

/// The backend's `description` field (both providers) is always plain English -- Open-Meteo's
/// side is `WeatherCodeMapper`'s own fixed 27-entry map (not translated by Open-Meteo itself,
/// computed by the backend from the WMO code), OpenWeatherMap's side is whatever English phrase
/// their API returns. Every client keyword-matches substrings of this same raw string for
/// condition-based styling (`WeatherConditionStyle`, the widget's emoji picker, etc.), so the
/// backend can't just start returning Portuguese -- that would break every client's styling
/// logic simultaneously. This translates *only for display*, in a PT-PT locale; the raw string
/// keeps flowing into styling untouched everywhere.
enum WeatherDescriptionLocalizer {
    /// Open-Meteo's fixed vocabulary (all 27 `WeatherCodeMapper` entries + its "Unknown"
    /// fallback) plus the OpenWeatherMap phrases most likely to actually appear as the fallback
    /// provider's output. OpenWeatherMap's vocabulary isn't a small fixed enum like Open-Meteo's,
    /// so this is deliberately best-effort for that side -- an unmapped phrase falls back to the
    /// original English rather than showing nothing.
    private static let portuguese: [String: String] = [
        "clear sky": "Céu limpo",
        "mainly clear": "Praticamente limpo",
        "partly cloudy": "Parcialmente nublado",
        "overcast": "Nublado",
        "fog": "Nevoeiro",
        "depositing rime fog": "Nevoeiro gelado",
        "light drizzle": "Chuvisco fraco",
        "moderate drizzle": "Chuvisco moderado",
        "dense drizzle": "Chuvisco intenso",
        "light freezing drizzle": "Chuvisco gelado fraco",
        "dense freezing drizzle": "Chuvisco gelado intenso",
        "slight rain": "Chuva fraca",
        "moderate rain": "Chuva moderada",
        "heavy rain": "Chuva forte",
        "light freezing rain": "Chuva gelada fraca",
        "heavy freezing rain": "Chuva gelada forte",
        "slight snow fall": "Neve fraca",
        "moderate snow fall": "Neve moderada",
        "heavy snow fall": "Neve forte",
        "snow grains": "Grãos de neve",
        "slight rain showers": "Aguaceiros fracos",
        "moderate rain showers": "Aguaceiros moderados",
        "violent rain showers": "Aguaceiros fortes",
        "slight snow showers": "Aguaceiros de neve fracos",
        "heavy snow showers": "Aguaceiros de neve fortes",
        "thunderstorm": "Trovoada",
        "thunderstorm with slight hail": "Trovoada com granizo fraco",
        "thunderstorm with heavy hail": "Trovoada com granizo forte",
        "unknown": "Desconhecido",
        // OpenWeatherMap (fallback provider) -- open vocabulary, best-effort coverage.
        "clear": "Céu limpo",
        "few clouds": "Poucas nuvens",
        "scattered clouds": "Nuvens dispersas",
        "broken clouds": "Céu muito nublado",
        "overcast clouds": "Céu encoberto",
        "light rain": "Chuva fraca",
        "moderate rain (openweathermap)": "Chuva moderada",
        "heavy intensity rain": "Chuva intensa",
        "shower rain": "Aguaceiros",
        "light intensity shower rain": "Aguaceiros fracos",
        "heavy intensity shower rain": "Aguaceiros fortes",
        "ragged shower rain": "Aguaceiros irregulares",
        "snow": "Neve",
        "light snow": "Neve fraca",
        "heavy snow": "Neve forte",
        "sleet": "Água-neve",
        "mist": "Neblina",
        "smoke": "Fumo",
        "haze": "Neblina seca",
        "sand/dust whirls": "Redemoinhos de areia/poeira",
        "dust": "Poeira",
        "sand": "Areia",
        "volcanic ash": "Cinza vulcânica",
        "squalls": "Rajadas de vento",
        "tornado": "Tornado",
    ]

    /// `raw` is always the backend's untouched English string -- pass it straight through
    /// (capitalized, matching the previous behavior everywhere) for any non-Portuguese locale,
    /// or when there's no translation for that exact phrase.
    static func localized(_ raw: String, locale: Locale) -> String {
        guard locale.language.languageCode?.identifier == "pt" else {
            return raw.capitalized
        }
        return portuguese[raw.lowercased()] ?? raw.capitalized
    }
}
