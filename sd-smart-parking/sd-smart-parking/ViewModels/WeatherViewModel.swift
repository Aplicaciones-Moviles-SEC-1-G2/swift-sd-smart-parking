import SwiftUI
import Combine

struct WeatherData {
    let temperature: Double
    let weatherCode: Int

    var symbolName: String {
        switch weatherCode {
        case 0, 1:       return "sun.max.fill"
        case 2:          return "cloud.sun.fill"
        case 3:          return "cloud.fill"
        case 45, 48:     return "cloud.fog.fill"
        case 51, 53, 55: return "cloud.drizzle.fill"
        case 61, 63, 65: return "cloud.rain.fill"
        case 71, 73, 75: return "cloud.snow.fill"
        case 80, 81, 82: return "cloud.heavyrain.fill"
        case 95, 96, 99: return "cloud.bolt.rain.fill"
        default:         return "cloud.fill"
        }
    }

    var symbolColor: Color {
        switch weatherCode {
        case 0, 1:       return .yellow
        case 2:          return .orange
        case 3:          return .gray
        case 45, 48:     return .gray
        case 51, 53, 55: return .blue
        case 61, 63, 65: return .blue
        case 71, 73, 75: return .cyan
        case 80, 81, 82: return .blue
        case 95, 96, 99: return .purple
        default:         return .secondary
        }
    }
}

@MainActor
class WeatherViewModel: ObservableObject {
    @Published var weather: WeatherData?
    @Published var isLoading = false

    // Coordinates of the SD Building parking (Bogotá)
    private let latitude  = 4.6014
    private let longitude = -74.0649

    init() {
        Task { await fetchWeather() }
    }

    func fetchWeather() async {
        isLoading = true
        defer { isLoading = false }

        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&current=temperature_2m,weather_code"
        guard let url = URL(string: urlString) else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json    = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let current = json["current"] as? [String: Any],
               let temp    = current["temperature_2m"] as? Double,
               let code    = current["weather_code"] as? Int {
                weather = WeatherData(temperature: temp, weatherCode: code)
            }
        } catch {
            print("Weather fetch error: \(error.localizedDescription)")
        }
    }
}
