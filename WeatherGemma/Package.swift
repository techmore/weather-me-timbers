// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WeatherGemma",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "WeatherGemma",
            dependencies: []
        )
    ]
)
