import Foundation
import CoreLocation
import Combine

// MARK: - Models

struct HourlyForecast: Identifiable {
    let id = UUID()
    let hour: String
    let temperature: String
    let symbolName: String
    let precipitationChance: Double
    let isNow: Bool
}

struct HomeWeatherState {
    let locationName: String
    let temperature: String
    let symbolName: String
    let condition: String
    let hourly: [HourlyForecast]
    let comfortText: String
    let isLoading: Bool
    let failed: Bool

    static let loading = HomeWeatherState(
        locationName: "", temperature: "--", symbolName: "cloud",
        condition: "", hourly: [], comfortText: "", isLoading: true, failed: false
    )

    static let denied = HomeWeatherState(
        locationName: "", temperature: "--", symbolName: "location.slash",
        condition: "Location access needed", hourly: [],
        comfortText: "Enable location in Settings to see weather.",
        isLoading: false, failed: true
    )
}

// MARK: - Open-Meteo Response

private struct OpenMeteoResponse: Decodable {
    let hourly: OpenMeteoHourly
    let current_weather: CurrentWeatherDTO
}

private struct OpenMeteoHourly: Decodable {
    let time: [String]
    let temperature_2m: [Double]
    let precipitation_probability: [Int]
    let weathercode: [Int]
}

private struct CurrentWeatherDTO: Decodable {
    let temperature: Double
    let weathercode: Int
    let windspeed: Double
}

// MARK: - Service

@MainActor
final class HomeWeatherService: NSObject, ObservableObject {
    static let shared = HomeWeatherService()

    @Published private(set) var state: HomeWeatherState = .loading

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var started = false

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func start() {
        guard !started else { return }
        started = true
        authorize()
    }

    func refresh() {
        locationManager.requestLocation()
    }

    // MARK: - Auth

    private func authorize() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            state = .denied
        default:
            locationManager.requestLocation()
        }
    }

    // MARK: - Fetch

    func fetch(location: CLLocation) async {
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude

        let urlString = "https://api.open-meteo.com/v1/forecast"
            + "?latitude=\(lat)&longitude=\(lon)"
            + "&hourly=temperature_2m,precipitation_probability,weathercode"
            + "&current_weather=true"
            + "&temperature_unit=fahrenheit"
            + "&forecast_days=2"
            + "&timezone=auto"

        guard let url = URL(string: urlString) else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)

            let placemark = try? await geocoder.reverseGeocodeLocation(location).first
            let city = placemark?.locality ?? "Here"

            let now = Date()
            let calendar = Calendar.current
            let currentHour = calendar.component(.hour, from: now)

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"

            // Find the index of the current hour in the response
            let startIndex = response.hourly.time.firstIndex(where: { timeStr in
                guard let date = formatter.date(from: timeStr) else { return false }
                return date >= calendar.startOfHour(for: now)
            }) ?? 0

            let hourFormatter = DateFormatter()
            hourFormatter.dateFormat = "ha"
            hourFormatter.amSymbol = "am"
            hourFormatter.pmSymbol = "pm"

            let hourly: [HourlyForecast] = response.hourly.time
                .enumerated()
                .filter { $0.offset >= startIndex && $0.offset < startIndex + 13 }
                .enumerated()
                .map { slotIndex, item in
                    let (originalIndex, timeStr) = item
                    let date = formatter.date(from: timeStr) ?? now
                    let temp = response.hourly.temperature_2m[originalIndex]
                    let code = response.hourly.weathercode[originalIndex]
                    let precip = response.hourly.precipitation_probability[originalIndex]

                    return HourlyForecast(
                        hour: slotIndex == 0 ? "Now" : hourFormatter.string(from: date).lowercased(),
                        temperature: "\(Int(temp.rounded()))°",
                        symbolName: sfSymbol(for: code, hour: calendar.component(.hour, from: date)),
                        precipitationChance: Double(precip) / 100.0,
                        isNow: slotIndex == 0
                    )
                }

            let currentCode = response.current_weather.weathercode
            let currentTemp = response.current_weather.temperature

            let nextTwelveHours = Array(response.hourly.time.enumerated()
                .filter { $0.offset >= startIndex && $0.offset < startIndex + 12 }
                .map { (index: $0.offset, code: response.hourly.weathercode[$0.offset],
                        precip: response.hourly.precipitation_probability[$0.offset],
                        time: $0.element) })

            let comfort = comfortText(
                currentCode: currentCode,
                currentHour: currentHour,
                nextHours: nextTwelveHours.map { (code: $0.code, precip: $0.precip, time: $0.time, formatter: formatter, hourFormatter: hourFormatter) }
            )

            state = HomeWeatherState(
                locationName: city,
                temperature: "\(Int(currentTemp.rounded()))°F",
                symbolName: sfSymbol(for: currentCode, hour: currentHour),
                condition: conditionLabel(for: currentCode),
                hourly: hourly,
                comfortText: comfort,
                isLoading: false,
                failed: false
            )
        } catch {
            state = HomeWeatherState(
                locationName: "", temperature: "--",
                symbolName: "exclamationmark.triangle",
                condition: "Weather unavailable", hourly: [],
                comfortText: "Could not load weather right now.",
                isLoading: false, failed: true
            )
        }
    }

    // MARK: - WMO Code → SF Symbol

    private func sfSymbol(for code: Int, hour: Int) -> String {
        let isNight = hour < 6 || hour >= 20
        switch code {
        case 0:
            return isNight ? "moon.stars.fill" : "sun.max.fill"
        case 1:
            return isNight ? "moon.fill" : "sun.min.fill"
        case 2:
            return isNight ? "cloud.moon.fill" : "cloud.sun.fill"
        case 3:
            return "cloud.fill"
        case 45, 48:
            return "cloud.fog.fill"
        case 51, 53, 55:
            return "cloud.drizzle.fill"
        case 61, 63:
            return "cloud.rain.fill"
        case 65:
            return "cloud.heavyrain.fill"
        case 71, 73, 75, 77:
            return "cloud.snow.fill"
        case 80, 81, 82:
            return "cloud.rain.fill"
        case 85, 86:
            return "cloud.snow.fill"
        case 95:
            return "cloud.bolt.fill"
        case 96, 99:
            return "cloud.bolt.rain.fill"
        default:
            return "cloud.fill"
        }
    }

    // MARK: - WMO Code → Label

    private func conditionLabel(for code: Int) -> String {
        switch code {
        case 0: return "Clear"
        case 1: return "Mainly Clear"
        case 2: return "Partly Cloudy"
        case 3: return "Overcast"
        case 45, 48: return "Foggy"
        case 51, 53, 55: return "Drizzle"
        case 61, 63, 65: return "Rain"
        case 71, 73, 75: return "Snow"
        case 77: return "Snow Grains"
        case 80, 81, 82: return "Rain Showers"
        case 85, 86: return "Snow Showers"
        case 95: return "Thunderstorm"
        case 96, 99: return "Thunderstorm"
        default: return "Cloudy"
        }
    }

    // MARK: - Comfort Text

    private func comfortText(
        currentCode: Int,
        currentHour: Int,
        nextHours: [(code: Int, precip: Int, time: String, formatter: DateFormatter, hourFormatter: DateFormatter)]
    ) -> String {
        let isRainy = { (code: Int) in (51...82).contains(code) || [95, 96, 99].contains(code) }
        let isSnowy = { (code: Int) in (71...77).contains(code) || [85, 86].contains(code) }
        let isThunder = { (code: Int) in [95, 96, 99].contains(code) }

        func timeLabel(_ slot: (code: Int, precip: Int, time: String, formatter: DateFormatter, hourFormatter: DateFormatter)) -> String {
            slot.formatter.date(from: slot.time).flatMap { slot.hourFormatter.string(from: $0).lowercased() } ?? "soon"
        }

        if let snowSlot = nextHours.first(where: { isSnowy($0.code) }) {
            let t = timeLabel(snowSlot)
            return [
                "Heads up — snow around \(t). Bundle up before you head out!",
                "Snow's coming around \(t). Hot cocoa weather incoming.",
                "Looks like \(t) brings snow. Layer up and stay cozy!"
            ].randomElement()!
        }

        if let stormSlot = nextHours.first(where: { isThunder($0.code) }) {
            let t = timeLabel(stormSlot)
            return [
                "Storms rolling in around \(t). Maybe a good time for that show you've been meaning to watch.",
                "Thunder expected near \(t). Stay cozy inside — you've earned it.",
                "Heads up, storms around \(t). Perfect excuse for a chill evening in."
            ].randomElement()!
        }

        if let heavySlot = nextHours.first(where: { $0.precip > 70 }) {
            let t = timeLabel(heavySlot)
            return [
                "Heavy rain around \(t) — grab your umbrella before heading out.",
                "Looks like it'll pour around \(t). Don't forget your rain jacket!",
                "Wet weather coming around \(t). A warm drink sounds perfect."
            ].randomElement()!
        }

        if let lightSlot = nextHours.first(where: { $0.precip > 40 }) {
            let t = timeLabel(lightSlot)
            return [
                "Light showers possible around \(t). A light layer should do the trick.",
                "A little rain near \(t) — nothing a jacket can't handle.",
                "Sprinkles around \(t). Still a good day to get things done."
            ].randomElement()!
        }

        if isRainy(currentCode) {
            let clearing = nextHours.first(where: { !isRainy($0.code) && $0.precip < 20 })
            if let clear = clearing,
               let date = clear.formatter.date(from: clear.time) {
                let t = clear.hourFormatter.string(from: date).lowercased()
                return [
                    "Rain should ease up around \(t). Hang in there!",
                    "Clearing up near \(t) — sunshine is on the way.",
                    "The rain's wrapping up around \(t). Better skies ahead."
                ].randomElement()!
            }
            return [
                "Rainy stretch ahead. A good day to tackle some indoor projects.",
                "The rain's sticking around for a bit. Stay dry out there!",
                "Cozy vibes only — the rain's here to stay for a while."
            ].randomElement()!
        }

        switch currentCode {
        case 0, 1:
            if currentHour < 7 {
                return [
                    "Early riser! It's going to be a gorgeous day.",
                    "Clear skies to start your day. Make the most of it!",
                    "Beautiful morning ahead — you're up at the best time."
                ].randomElement()!
            }
            if currentHour < 12 {
                return [
                    "What a morning! Perfect weather to step outside.",
                    "Sunny and clear — a great day to get things done.",
                    "The sun is out and so should you. Enjoy your morning!"
                ].randomElement()!
            }
            if currentHour < 17 {
                return [
                    "Clear skies all afternoon. Treat yourself to some fresh air.",
                    "Lovely afternoon ahead — great for a walk or a coffee run.",
                    "Sun's shining bright. Hope you're having a good one!"
                ].randomElement()!
            }
            if currentHour < 21 {
                return [
                    "Beautiful evening. Perfect for winding down outside.",
                    "Clear skies tonight — enjoy the sunset if you can.",
                    "What a nice evening. You deserve a peaceful one."
                ].randomElement()!
            }
            return [
                "Clear night sky. Rest well — tomorrow looks great too.",
                "Peaceful night ahead. Sleep tight!",
                "Stars are out tonight. Hope you had a wonderful day."
            ].randomElement()!
        case 2, 3:
            return [
                "A bit cloudy, but no rain coming. You're in the clear!",
                "Overcast but calm — a chill kind of day.",
                "Clouds are hanging around, but nothing to worry about."
            ].randomElement()!
        case 45, 48:
            return [
                "Foggy out there — take it easy on the road.",
                "Misty vibes today. It'll clear up soon enough.",
                "A little hazy right now. Drive safe!"
            ].randomElement()!
        default:
            return [
                "Steady conditions for the next few hours. You're all set!",
                "Nothing dramatic on the radar. Enjoy your day!",
                "Smooth sailing weather-wise. Have a great one!"
            ].randomElement()!
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension HomeWeatherService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        _Concurrency.Task {
            await MainActor.run { [weak self] in self?.authorize() }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        manager.stopUpdatingLocation()
        _Concurrency.Task {
            await MainActor.run { [weak self] in
                _Concurrency.Task { await self?.fetch(location: location) }
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        _Concurrency.Task {
            await MainActor.run { [weak self] in
                self?.state = HomeWeatherState(
                    locationName: "", temperature: "--",
                    symbolName: "location.slash",
                    condition: "Location unavailable", hourly: [],
                    comfortText: "Could not determine your location.",
                    isLoading: false, failed: true
                )
            }
        }
    }
}

// MARK: - Calendar helper

private extension Calendar {
    func startOfHour(for date: Date) -> Date {
        let components = dateComponents([.year, .month, .day, .hour], from: date)
        return self.date(from: components) ?? date
    }
}
