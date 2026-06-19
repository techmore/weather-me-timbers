import Foundation

@MainActor
@Observable
final class WeatherService {
    var currentWeather: WeatherData?
    var forecastState: ForecastState = .idle
    var isLoading = false
    var error: String?
    var lastUpdated: Date?

    private let decoder = JSONDecoder()

    // MARK: - Public API

    func fetchWeather(lat: Double, lon: Double, settings: SettingsStore) async {
        isLoading = true
        error = nil

        do {
            if settings.useCustomScript, !settings.customScriptPath.isEmpty {
                currentWeather = try await runCustomScript(path: settings.customScriptPath, lat: lat, lon: lon, units: settings.temperatureUnit)
                forecastState = .loaded(hourly: [], days: [])
            } else {
                try await fetchOpenMeteoFull(lat: lat, lon: lon, unit: settings.temperatureUnit)
            }
            lastUpdated = Date()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Open-Meteo (current + hourly + daily)

    private func fetchOpenMeteoFull(lat: Double, lon: Double, unit: String) async throws {
        let tempUnit = unit == "celsius" ? "celsius" : "fahrenheit"
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m&hourly=temperature_2m,weather_code,precipitation_probability,wind_speed_10m&daily=temperature_2m_max,temperature_2m_min,weather_code&temperature_unit=\(tempUnit)&wind_speed_unit=mph&timezone=auto&forecast_days=3"

        guard let url = URL(string: urlString) else { throw WeatherError.invalidURL }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse else { throw WeatherError.badResponse }
        guard http.statusCode == 200 else { throw WeatherError.httpError(http.statusCode) }

        let api = try decoder.decode(OpenMeteoResponse.self, from: data)
        let now = Date()

        // Current
        currentWeather = WeatherData(
            temperature: api.current.temperature2m,
            feelsLike: api.current.apparentTemperature,
            humidity: api.current.relativeHumidity2m,
            windSpeed: api.current.windSpeed10m,
            conditionCode: api.current.weatherCode
        )

        // Hourly
        var hourly: [HourlyEntry] = []
        if let h = api.hourly {
            for i in h.time.indices {
                guard i < h.temperature2m.count,
                      i < h.weatherCode.count,
                      i < h.precipitationProbability.count,
                      i < h.windSpeed10m.count else { break }
                guard let date = isoParser.date(from: h.time[i]), date >= now else { continue }

                hourly.append(HourlyEntry(
                    date: date,
                    temperature: h.temperature2m[i],
                    weatherCode: h.weatherCode[i],
                    precipitationProbability: h.precipitationProbability[i],
                    windSpeed: h.windSpeed10m[i]
                ))
            }
        }

        // Daily
        var days: [DayForecast] = []
        if let d = api.daily {
            let cal = Calendar.current
            for i in d.time.indices {
                guard i < d.temperature2mMax.count,
                      i < d.temperature2mMin.count,
                      i < d.weatherCode.count else { break }
                guard let date = isoParser.date(from: d.time[i]) else { continue }

                let isToday = cal.isDateInToday(date)
                let name = isToday ? "Today" : (cal.isDateInTomorrow(date) ? "Tomorrow" : dayFormatter.string(from: date))

                days.append(DayForecast(
                    date: date,
                    dayName: name,
                    highTemp: d.temperature2mMax[i],
                    lowTemp: d.temperature2mMin[i],
                    conditionCode: d.weatherCode[i]
                ))
            }
        }

        forecastState = .loaded(hourly: hourly, days: days)
    }

    // MARK: - Custom Script

    private func runCustomScript(path: String, lat: Double, lon: Double, units: String) async throws -> WeatherData {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [path, "--lat", "\(lat)", "--lon", "\(lon)", "--units", units]

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let msg = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "exit code \(process.terminationStatus)"
            throw WeatherError.scriptFailed(msg)
        }

        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        guard data.count > 0 else { throw WeatherError.scriptFailed("no output") }

        do {
            return try decoder.decode(WeatherData.self, from: data)
        } catch {
            throw WeatherError.decodingFailed(error.localizedDescription)
        }
    }
}
