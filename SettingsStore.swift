import Foundation

@Observable
final class SettingsStore {
    var ollamaHost: String        { didSet { UserDefaults.standard.set(ollamaHost,        forKey: "ollamaHost") } }
    var modelName: String         { didSet { UserDefaults.standard.set(modelName,         forKey: "modelName") } }
    var ollamaTemperature: Double { didSet { UserDefaults.standard.set(ollamaTemperature, forKey: "ollamaTemperature") } }
    var refreshInterval: Double   { didSet { UserDefaults.standard.set(refreshInterval,   forKey: "refreshInterval") } }
    var temperatureUnit: String   { didSet { UserDefaults.standard.set(temperatureUnit,   forKey: "temperatureUnit") } }
    var useCustomScript: Bool     { didSet { UserDefaults.standard.set(useCustomScript,   forKey: "useCustomScript") } }
    var customScriptPath: String  { didSet { UserDefaults.standard.set(customScriptPath,  forKey: "customScriptPath") } }
    var useManualLocation: Bool   { didSet { UserDefaults.standard.set(useManualLocation, forKey: "useManualLocation") } }
    var manualLatitude: Double    { didSet { UserDefaults.standard.set(manualLatitude,    forKey: "manualLatitude") } }
    var manualLongitude: Double   { didSet { UserDefaults.standard.set(manualLongitude,   forKey: "manualLongitude") } }
    var manualCityName: String    { didSet { UserDefaults.standard.set(manualCityName,    forKey: "manualCityName") } }

    init() {
        let defaults = UserDefaults.standard
        ollamaHost        = defaults.string(forKey: "ollamaHost")        ?? "http://localhost:11434"
        modelName         = defaults.string(forKey: "modelName")         ?? "gemma4:e4b"
        ollamaTemperature = defaults.object(forKey: "ollamaTemperature") as? Double ?? 0.35
        refreshInterval   = defaults.object(forKey: "refreshInterval")   as? Double ?? 20
        temperatureUnit   = defaults.string(forKey: "temperatureUnit")   ?? "fahrenheit"
        useCustomScript   = defaults.bool(forKey: "useCustomScript")
        customScriptPath  = defaults.string(forKey: "customScriptPath")  ?? ""
        useManualLocation = defaults.bool(forKey: "useManualLocation")
        manualLatitude    = defaults.object(forKey: "manualLatitude")    as? Double ?? 37.7749
        manualLongitude   = defaults.object(forKey: "manualLongitude")   as? Double ?? -122.4194
        manualCityName    = defaults.string(forKey: "manualCityName")    ?? "San Francisco"
    }
}
