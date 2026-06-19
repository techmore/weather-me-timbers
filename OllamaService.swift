import Foundation

@MainActor
@Observable
final class OllamaService {
    var insight: String?
    var isLoading = false
    var error: String?

    // MARK: - Generate Insight

    func generateInsight(weather: WeatherData, location: String, settings: SettingsStore) async {
        isLoading = true
        insight = nil
        error = nil

        do {
            let response = try await callOllama(weather: weather, location: location, settings: settings)
            insight = response
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func testConnection(host: String) async -> String {
        guard let url = URL(string: "\(host)/api/tags") else { return "Invalid host URL" }
        do {
            var req = URLRequest(url: url)
            req.timeoutInterval = 5
            let (data, _) = try await URLSession.shared.data(for: req)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let models = (json?["models"] as? [[String: Any]]) ?? []
            return "OK – \(models.count) model(s) available"
        } catch {
            return "Failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Ollama API

    private func callOllama(weather: WeatherData, location: String, settings: SettingsStore) async throws -> String {
        guard let url = URL(string: "\(settings.ollamaHost)/api/chat") else {
            throw OllamaError.generationFailed("Invalid Ollama host")
        }

        let systemPrompt = """
        You are a concise, witty weather commentator. Respond in exactly 1–2 sentences, under 45 words. \
        Make it practical and slightly humorous. No greetings. No markdown.
        """

        let userMessage = """
        Location: \(location)
        Temperature: \(weather.temperatureFormatted), Feels like: \(weather.feelsLikeFormatted)
        Condition: \(WeatherIconMapper.description(for: weather.conditionCode))
        Humidity: \(weather.humidityFormatted), Wind: \(weather.windSpeedFormatted)
        """

        let body: [String: Any] = [
            "model": settings.modelName,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user",   "content": userMessage]
            ],
            "options": [
                "temperature": settings.ollamaTemperature
            ],
            "stream": false
        ]

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 30
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)

        guard let http = response as? HTTPURLResponse else { throw OllamaError.badResponse }

        if http.statusCode == 404 {
            throw OllamaError.modelNotFound(settings.modelName)
        }
        guard http.statusCode == 200 else {
            let msg = http.statusCode == 503 ? "Ollama is loading the model. Try again in a few seconds." : "HTTP \(http.statusCode)"
            throw OllamaError.generationFailed(msg)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let messageDict = json["message"] as? [String: Any],
              let content = messageDict["content"] as? String,
              !content.isEmpty
        else {
            throw OllamaError.badResponse
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\"", with: "")
    }
}
