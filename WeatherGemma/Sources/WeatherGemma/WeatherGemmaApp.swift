import SwiftUI

@main
struct WeatherGemmaApp: App {
    @State private var weatherService = WeatherService()
    @State private var locationService = LocationService()
    @State private var ollamaService = OllamaService()
    @State private var settings = SettingsStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(weatherService)
                .environment(locationService)
                .environment(ollamaService)
                .environment(settings)
                .frame(width: 340)
                .fixedSize(horizontal: false, vertical: true)
        }
        .windowResizability(.contentSize)
        .windowTitle("WeatherGemma")

        MenuBarExtra {
            ContentView()
                .environment(weatherService)
                .environment(locationService)
                .environment(ollamaService)
                .environment(settings)
        } label: {
            if let weather = weatherService.currentWeather {
                HStack(spacing: 4) {
                    Image(systemName: WeatherIconMapper.symbol(for: weather.conditionCode))
                    Text(weather.temperatureFormatted)
                }
            } else {
                Image(systemName: "thermometer.medium")
            }
        }
        .menuBarExtraStyle(.window)
    }
}
