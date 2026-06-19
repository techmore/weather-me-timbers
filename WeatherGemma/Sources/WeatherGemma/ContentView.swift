import SwiftUI
import Charts

struct ContentView: View {
    @Environment(WeatherService.self)  private var weatherService
    @Environment(LocationService.self) private var locationService
    @Environment(OllamaService.self)   private var ollamaService
    @Environment(SettingsStore.self)   private var settings

    @State private var showSettings = false

    private let popoverWidth: CGFloat = 340

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(spacing: 0) {
                    if weatherService.isLoading && weatherService.currentWeather == nil {
                        loadingView
                            .padding(.vertical, 40)
                    } else if let error = weatherService.error, weatherService.currentWeather == nil {
                        errorView(error)
                            .padding(.vertical, 40)
                    } else if let weather = weatherService.currentWeather {
                        heroSection(weather)
                        secondaryRow(weather)
                        Divider().padding(.horizontal, 16)
                        insightSection(weather)
                        Divider().padding(.horizontal, 16)
                        forecastSection
                    } else {
                        loadingView
                            .padding(.vertical, 40)
                    }
                }
            }
            Divider()
            footer
        }
        .frame(width: popoverWidth)
        .task { locationService.requestLocation() }
        .task { await refreshLoop() }
        .onChange(of: locationService.location?.latitude) { _, _ in
            guard let loc = locationService.location else { return }
            Task { await weatherService.fetchWeather(lat: loc.latitude, lon: loc.longitude, settings: settings) }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text(locationService.cityName)
                .font(.headline)
                .fontWeight(.semibold)
            Spacer()
            if let updated = weatherService.lastUpdated {
                Text("Updated \(relative(from: updated))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button { refresh() } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .disabled(weatherService.isLoading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Hero

    private func heroSection(_ w: WeatherData) -> some View {
        VStack(spacing: 4) {
            Image(systemName: WeatherIconMapper.symbol(for: w.conditionCode))
                .font(.system(size: 44))
                .symbolRenderingMode(.multicolor)
            Text(w.temperatureFormatted)
                .font(.system(size: 50, weight: .thin, design: .rounded))
            Text(WeatherIconMapper.description(for: w.conditionCode))
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Secondary Row

    private func secondaryRow(_ w: WeatherData) -> some View {
        HStack(spacing: 0) {
            statBlock(label: "Feels Like", value: w.feelsLikeFormatted, icon: "thermometer.variable.and.figure")
            Divider().frame(height: 30)
            statBlock(label: "Humidity",   value: w.humidityFormatted,  icon: "humidity")
            Divider().frame(height: 30)
            statBlock(label: "Wind",       value: w.windSpeedFormatted, icon: "wind")
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }

    private func statBlock(label: String, value: String, icon: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.body, design: .rounded).weight(.medium))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Insight

    private func insightSection(_ w: WeatherData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(.tint)
                Text("Gemma's Insight")
                    .font(.headline)
            }

            if ollamaService.isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Thinking…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } else if let insight = ollamaService.insight {
                Text(insight)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let error = ollamaService.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            } else {
                Text("Tap generate for a local AI take on today's weather.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Button {
                Task { await ollamaService.generateInsight(weather: w, location: locationService.cityName, settings: settings) }
            } label: {
                Label(ollamaService.insight == nil ? "Generate Insight" : "Regenerate", systemImage: "sparkles")
                    .font(.caption)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(ollamaService.isLoading)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.quaternary.opacity(0.35))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Forecast

    @ViewBuilder
    private var forecastSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Forecast", systemImage: "calendar")
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.top, 10)

            switch weatherService.forecastState {
            case .idle, .loading:
                HStack {
                    Spacer()
                    ProgressView().scaleEffect(0.6)
                    Text("Loading forecast…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.vertical, 8)

            case .loaded(let hourly, let days):
                if !days.isEmpty {
                    dailyCards(days)
                }
                if !hourly.isEmpty {
                    temperatureChart(hourly)
                    hourlyScroll(hourly)
                }

            case .error(let msg):
                HStack {
                    Spacer()
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.red)
                    Spacer()
                }
                .padding(.vertical, 8)
            }
        }
        .padding(.bottom, 12)
    }

    private func dailyCards(_ days: [DayForecast]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(days) { day in
                    VStack(spacing: 4) {
                        Text(day.dayName)
                            .font(.caption2.weight(.semibold))
                        Image(systemName: WeatherIconMapper.symbol(for: day.conditionCode))
                            .font(.title3)
                            .symbolRenderingMode(.multicolor)
                        Text("\(Int(round(day.highTemp)))°")
                            .font(.callout.weight(.medium))
                        Text("\(Int(round(day.lowTemp)))°")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 56)
                    .padding(6)
                    .background {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(.quaternary.opacity(0.3))
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func temperatureChart(_ hourly: [HourlyEntry]) -> some View {
        let next24 = Array(hourly.prefix(24))
        guard !next24.isEmpty else { return AnyView(EmptyView()) }

        let minT = next24.map(\.temperature).min() ?? 0
        let maxT = next24.map(\.temperature).max() ?? 100
        let range = maxT - minT
        let bottomPad = range < 1 ? 5.0 : range * 0.15

        return AnyView(
            Chart(next24) { entry in
                LineMark(
                    x: .value("Time", entry.date),
                    y: .value("Temp", entry.temperature)
                )
                .foregroundStyle(
                    LinearGradient(colors: [.blue, .orange, .red], startPoint: .bottom, endPoint: .top)
                )
                .lineStyle(.init(lineWidth: 1.5))

                AreaMark(
                    x: .value("Time", entry.date),
                    y: .value("Temp", entry.temperature)
                )
                .foregroundStyle(
                    LinearGradient(colors: [.orange.opacity(0.15), .clear], startPoint: .top, endPoint: .bottom)
                )
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: (minT - bottomPad)...(maxT + bottomPad))
            .frame(height: 36)
            .padding(.horizontal, 16)
        )
    }

    private func hourlyScroll(_ hourly: [HourlyEntry]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(hourly) { entry in
                    VStack(spacing: 3) {
                        Text(hourFormatter.string(from: entry.date).lowercased())
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                        Image(systemName: WeatherIconMapper.symbol(for: entry.weatherCode))
                            .font(.system(size: 14))
                            .symbolRenderingMode(.multicolor)
                        Text("\(Int(round(entry.temperature)))°")
                            .font(.system(size: 11, weight: .medium))
                        if entry.precipitationProbability > 10 {
                            Text("\(entry.precipitationProbability)%")
                                .font(.system(size: 8))
                                .foregroundStyle(.blue)
                        }
                    }
                    .frame(width: 36)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.quaternary.opacity(0.2))
                .padding(.horizontal, 12)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Settings") { showSettings = true }
                .buttonStyle(.plain)
                .font(.caption)
            Spacer()
            if let updated = weatherService.lastUpdated {
                Text(updated.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Loading / Error

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Fetching weather…")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.orange)
            Text(msg)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            Button("Retry") { refresh() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
    }

    // MARK: - Helpers

    private func refresh() {
        guard let loc = locationService.location else { return }
        Task { await weatherService.fetchWeather(lat: loc.latitude, lon: loc.longitude, settings: settings) }
    }

    private func refreshLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(max(settings.refreshInterval * 60, 60)))
            guard let loc = locationService.location else { continue }
            await weatherService.fetchWeather(lat: loc.latitude, lon: loc.longitude, settings: settings)
        }
    }

    private func relative(from date: Date) -> String {
        let d = -date.timeIntervalSinceNow
        if d < 60 { return "just now" }
        let m = Int(d / 60)
        return "\(m) min ago"
    }
}
