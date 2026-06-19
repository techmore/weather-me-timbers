import SwiftUI
import AppKit

@main
struct WeatherGemmaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
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
                .onAppear {
                    appDelegate.setup(with: AppServices(
                        weather: weatherService,
                        location: locationService,
                        ollama: ollamaService,
                        settings: settings
                    ))
                }
        }
        .windowResizability(.contentMinSize)
    }
}

struct AppServices {
    let weather: WeatherService
    let location: LocationService
    let ollama: OllamaService
    let settings: SettingsStore
}

// MARK: - AppDelegate (manages NSStatusItem + popover)
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var services: AppServices?
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var monitoringEvent: Any?

    func setup(with services: AppServices) {
        self.services = services
        guard statusItem == nil else { return }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateMenuBarIcon()

        let content = ContentView()
            .environment(services.weather)
            .environment(services.location)
            .environment(services.ollama)
            .environment(services.settings)
            .frame(width: 340)

        let hosting = NSHostingController(rootView: content)
        popover = NSPopover()
        popover?.behavior = .transient
        popover?.contentViewController = hosting

        observeWeatherChanges()
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let popover, let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(sender)
            removeMonitor()
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            monitorPopoverClose()
        }
    }

    private func monitorPopoverClose() {
        removeMonitor()
        monitoringEvent = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { _ in
            Task { @MainActor [weak self] in
                self?.popover?.performClose(nil)
                self?.removeMonitor()
            }
        }
    }

    private func removeMonitor() {
        if let ev = monitoringEvent {
            NSEvent.removeMonitor(ev)
            monitoringEvent = nil
        }
    }

    func updateMenuBarIcon() {
        guard let button = statusItem?.button else { return }
        let icon: String
        let title: String

        if let weather = services?.weather.currentWeather {
            icon = WeatherIconMapper.symbol(for: weather.conditionCode)
            title = " \(weather.temperatureFormatted)"
        } else {
            icon = "thermometer.medium"
            title = ""
        }

        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        if let img = NSImage(systemSymbolName: icon, accessibilityDescription: "Weather")?.withSymbolConfiguration(config) {
            let attachment = NSTextAttachment()
            attachment.image = img
            let attrStr = NSMutableAttributedString(attachment: attachment)
            attrStr.append(NSAttributedString(string: title, attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
                .foregroundColor: NSColor.labelColor
            ]))
            button.attributedTitle = attrStr
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    func observeWeatherChanges() {
        guard let weather = services?.weather else { return }
        withObservationTracking {
            _ = weather.currentWeather
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.updateMenuBarIcon()
                self?.observeWeatherChanges()
            }
        }
    }
}
