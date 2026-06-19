import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SettingsStore.self) private var settings

    @State private var connectionResult: String?
    @State private var isTesting = false

    var body: some View {
        @Bindable var s = settings

        Form {
            Section("General") {
                Picker("Temperature Unit", selection: $s.temperatureUnit) {
                    Text("Fahrenheit").tag("fahrenheit")
                    Text("Celsius").tag("celsius")
                }

                Stepper("Refresh every \(Int(s.refreshInterval)) min",
                        value: $s.refreshInterval, in: 5...60, step: 5)
            }

            Section("Location") {
                Toggle("Use Manual Location", isOn: $s.useManualLocation)

                if s.useManualLocation {
                    HStack {
                        TextField("Latitude", value: $s.manualLatitude, format: .number)
                        TextField("Longitude", value: $s.manualLongitude, format: .number)
                    }
                    TextField("City Name", text: $s.manualCityName)
                }
            }

            Section("Weather Source") {
                Toggle("Use Custom Script", isOn: $s.useCustomScript)

                if s.useCustomScript {
                    HStack {
                        TextField("Script Path", text: $s.customScriptPath)
                            .font(.caption)
                            .autocorrectionDisabled()
                        Button("Browse") {
                            let panel = NSOpenPanel()
                            panel.allowedContentTypes = [.unixExecutable, .shellScript]
                            panel.canChooseFiles = true
                            panel.canChooseDirectories = false
                            panel.begin { resp in
                                if resp == .OK, let url = panel.url {
                                    s.customScriptPath = url.path
                                }
                            }
                        }
                        .controlSize(.small)
                    }
                }
            }

            Section("Ollama") {
                TextField("Host", text: $s.ollamaHost)
                    .autocorrectionDisabled()
                TextField("Model", text: $s.modelName)
                    .autocorrectionDisabled()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Temperature: \(s.ollamaTemperature, specifier: "%.2f")")
                        .font(.caption)
                    Slider(value: $s.ollamaTemperature, in: 0...1, step: 0.05)
                }

                HStack {
                    Button("Test Connection") {
                        isTesting = true
                        connectionResult = nil
                        Task {
                            let result = await OllamaService().testConnection(host: s.ollamaHost)
                            connectionResult = result
                            isTesting = false
                        }
                    }
                    .disabled(isTesting)

                    if isTesting {
                        ProgressView()
                            .scaleEffect(0.6)
                    }

                    if let result = connectionResult {
                        Text(result)
                            .font(.caption)
                            .foregroundStyle(result.hasPrefix("OK") ? .green : .red)
                    }
                }
            }

            Section {
                HStack {
                    Spacer()
                    Button("Done") { dismiss() }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 480)
    }
}
