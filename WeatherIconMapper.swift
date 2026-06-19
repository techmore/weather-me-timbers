import Foundation

enum WeatherIconMapper {
    static func symbol(for code: Int) -> String {
        switch code {
        case 0:             return "sun.max.fill"
        case 1:             return "sun.min.fill"
        case 2:             return "cloud.sun.fill"
        case 3:             return "cloud.fill"
        case 45, 48:        return "cloud.fog.fill"
        case 51, 53, 55:    return "cloud.drizzle.fill"
        case 56, 57:        return "cloud.sleet.fill"
        case 61, 63, 65:    return "cloud.rain.fill"
        case 66, 67:        return "cloud.sleet.fill"
        case 71, 73, 75:    return "cloud.snow.fill"
        case 77:            return "cloud.snow.fill"
        case 80, 81, 82:    return "cloud.heavyrain.fill"
        case 85, 86:        return "cloud.snow.fill"
        case 95:            return "cloud.bolt.fill"
        case 96, 99:        return "cloud.bolt.rain.fill"
        default:            return "questionmark"
        }
    }

    static func description(for code: Int) -> String {
        switch code {
        case 0:             return "Clear"
        case 1:             return "Mostly Clear"
        case 2:             return "Partly Cloudy"
        case 3:             return "Overcast"
        case 45, 48:        return "Foggy"
        case 51, 53, 55:    return "Drizzle"
        case 56, 57:        return "Freezing Drizzle"
        case 61, 63, 65:    return "Rain"
        case 66, 67:        return "Freezing Rain"
        case 71, 73, 75:    return "Snow"
        case 77:            return "Snow Grains"
        case 80, 81, 82:    return "Rain Showers"
        case 85, 86:        return "Snow Showers"
        case 95:            return "Thunderstorm"
        case 96, 99:        return "Thunderstorm with Hail"
        default:            return "Unknown"
        }
    }
}
