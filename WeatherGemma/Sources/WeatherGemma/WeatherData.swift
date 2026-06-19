import Foundation

// MARK: - Open-Meteo API Response
struct OpenMeteoResponse: Decodable, Sendable {
    let current: Current
    let hourly: Hourly?
    let daily: Daily?

    struct Current: Decodable, Sendable {
        let temperature2m: Double
        let relativeHumidity2m: Int
        let apparentTemperature: Double
        let weatherCode: Int
        let windSpeed10m: Double

        enum CodingKeys: String, CodingKey {
            case temperature2m = "temperature_2m"
            case relativeHumidity2m = "relative_humidity_2m"
            case apparentTemperature = "apparent_temperature"
            case weatherCode = "weather_code"
            case windSpeed10m = "wind_speed_10m"
        }
    }

    struct Hourly: Decodable, Sendable {
        let time: [String]
        let temperature2m: [Double]
        let weatherCode: [Int]
        let precipitationProbability: [Int]
        let windSpeed10m: [Double]

        enum CodingKeys: String, CodingKey {
            case time
            case temperature2m = "temperature_2m"
            case weatherCode = "weather_code"
            case precipitationProbability = "precipitation_probability"
            case windSpeed10m = "wind_speed_10m"
        }
    }

    struct Daily: Decodable, Sendable {
        let time: [String]
        let temperature2mMax: [Double]
        let temperature2mMin: [Double]
        let weatherCode: [Int]

        enum CodingKeys: String, CodingKey {
            case time
            case temperature2mMax = "temperature_2m_max"
            case temperature2mMin = "temperature_2m_min"
            case weatherCode = "weather_code"
        }
    }
}

// MARK: - Internal Weather Model
struct WeatherData: Codable, Sendable {
    let temperature: Double
    let feelsLike: Double
    let humidity: Int
    let windSpeed: Double
    let conditionCode: Int

    var temperatureFormatted: String { "\(Int(round(temperature)))°" }
    var feelsLikeFormatted: String { "\(Int(round(feelsLike)))°" }
    var humidityFormatted: String { "\(humidity)%" }
    var windSpeedFormatted: String { "\(Int(round(windSpeed))) mph" }
}

// MARK: - Forecast Models
struct HourlyEntry: Identifiable, Sendable {
    let id = UUID()
    let date: Date
    let temperature: Double
    let weatherCode: Int
    let precipitationProbability: Int
    let windSpeed: Double
}

struct DayForecast: Identifiable, Sendable {
    let id = UUID()
    let date: Date
    let dayName: String
    let highTemp: Double
    let lowTemp: Double
    let conditionCode: Int
}

enum ForecastState: Sendable {
    case idle
    case loading
    case loaded(hourly: [HourlyEntry], days: [DayForecast])
    case error(String)
}

// MARK: - Errors
enum WeatherError: LocalizedError, Sendable {
    case invalidURL
    case httpError(Int)
    case badResponse
    case scriptFailed(String)
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:               return "Invalid URL"
        case .httpError(let code):      return "HTTP \(code)"
        case .badResponse:              return "Unexpected response format"
        case .scriptFailed(let msg):    return "Script: \(msg)"
        case .decodingFailed(let msg):  return "Decoding: \(msg)"
        }
    }
}

enum OllamaError: LocalizedError, Sendable {
    case notRunning
    case modelNotFound(String)
    case generationFailed(String)
    case badResponse

    var errorDescription: String? {
        switch self {
        case .notRunning:              return "Ollama is not running.\nStart it with: ollama serve"
        case .modelNotFound(let m):    return "Model '\(m)' not found.\nPull it: ollama pull \(m)"
        case .generationFailed(let m): return m
        case .badResponse:             return "Unexpected response from Ollama"
        }
    }
}

// MARK: - Convenience helpers
let isoParser: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd'T'HH:mm"
    f.timeZone = TimeZone(secondsFromGMT: 0)
    return f
}()

let hourFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "ha"
    return f
}()

let dayFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "E d"
    return f
}()

let fullDayFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "EEEE"
    return f
}()
