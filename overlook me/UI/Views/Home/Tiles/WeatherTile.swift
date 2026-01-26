import SwiftUI
import CoreLocation
import Combine

struct WeatherData {
    let temp: Int
    let condition: String
    let icon: String
    let high: Int
    let low: Int
    let humidity: Int
    
    static let placeholder = WeatherData(
        temp: 0,
        condition: "--",
        icon: "cloud.fill",
        high: 0,
        low: 0,
        humidity: 0
    )
}

struct WeatherTile: View {
    let weather: WeatherData
    let onTap: () -> Void
    
    @State private var showHourlySheet = false
    @StateObject private var tileViewModel = WeatherTileViewModel()
    
    var body: some View {
        Button {
            showHourlySheet = true
        } label: {
            VStack(spacing: 6) {
                // Location pill
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 8))
                    Text(tileViewModel.cityName)
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.fill.tertiary, in: Capsule())
                
                if tileViewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: tileViewModel.icon)
                        .font(.system(size: 32))
                        .symbolRenderingMode(.multicolor)
                    
                    Text("\(tileViewModel.temp)°")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                    
                    Text(tileViewModel.condition)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    
                    Text("H:\(tileViewModel.high)° L:\(tileViewModel.low)°")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .glassTile()
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showHourlySheet) {
            WeatherDetailSheet()
        }
        .onAppear {
            tileViewModel.fetchWeather()
        }
    }
}

// MARK: - Weather Tile ViewModel (for the small tile)

@MainActor
private final class WeatherTileViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var cityName = "--"
    @Published var temp = 0
    @Published var condition = "--"
    @Published var icon = "cloud.fill"
    @Published var high = 0
    @Published var low = 0
    @Published var isLoading = true
    
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }
    
    func fetchWeather() {
        isLoading = true
        let status = locationManager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.requestLocation()
        } else if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else {
            isLoading = false
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        _Concurrency.Task {
            // Get city name
            if let placemark = try? await geocoder.reverseGeocodeLocation(location).first {
                cityName = placemark.locality ?? placemark.name ?? "Unknown"
            }
            // Fetch weather
            await loadWeather(for: location)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLoading = false
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }
    
    private func loadWeather(for location: CLLocation) async {
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,weather_code&daily=temperature_2m_max,temperature_2m_min&temperature_unit=fahrenheit&forecast_days=1"
        
        guard let url = URL(string: urlString) else { isLoading = false; return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(TileWeatherResponse.self, from: data)
            
            temp = Int(response.current.temperature_2m)
            icon = weatherIcon(for: response.current.weather_code)
            condition = weatherCondition(for: response.current.weather_code)
            if let daily = response.daily {
                high = Int(daily.temperature_2m_max[0])
                low = Int(daily.temperature_2m_min[0])
            }
            isLoading = false
        } catch {
            isLoading = false
        }
    }
    
    private func weatherIcon(for code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1, 2, 3: return "cloud.sun.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55: return "cloud.drizzle.fill"
        case 61, 63, 65: return "cloud.rain.fill"
        case 71, 73, 75: return "cloud.snow.fill"
        case 80, 81, 82: return "cloud.heavyrain.fill"
        case 95, 96, 99: return "cloud.bolt.fill"
        default: return "cloud.fill"
        }
    }
    
    private func weatherCondition(for code: Int) -> String {
        switch code {
        case 0: return "Clear"
        case 1: return "Mainly Clear"
        case 2: return "Partly Cloudy"
        case 3: return "Overcast"
        case 45, 48: return "Foggy"
        case 51, 53, 55: return "Drizzle"
        case 61, 63, 65: return "Rain"
        case 71, 73, 75: return "Snow"
        case 80, 81, 82: return "Showers"
        case 95, 96, 99: return "Thunderstorm"
        default: return "Cloudy"
        }
    }
}

private struct TileWeatherResponse: Codable {
    let current: Current
    let daily: Daily?
    
    struct Current: Codable {
        let temperature_2m: Double
        let weather_code: Int
    }
    
    struct Daily: Codable {
        let temperature_2m_max: [Double]
        let temperature_2m_min: [Double]
    }
}

// MARK: - Models

struct HourlyForecast: Identifiable {
    let id = UUID()
    let date: Date
    let temp: Int
    let icon: String
    let precipitation: Int
}

struct DailyForecast: Identifiable {
    let id = UUID()
    let date: Date
    let high: Int
    let low: Int
    let icon: String
    let precipitation: Int
}

struct CurrentWeatherData {
    let temp: Int
    let feelsLike: Int
    let condition: String
    let icon: String
    let high: Int
    let low: Int
    let humidity: Int
    let windSpeed: Int
    let uvIndex: Int
    let visibility: Int
    let pressure: Int
}

// MARK: - Weather Detail Sheet (Native iOS 26 Glass)

private struct WeatherDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel = WeatherDetailViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Dark gradient background
                LinearGradient(
                    colors: colorScheme == .dark 
                        ? [Color(white: 0.1), Color(white: 0.05)]
                        : [Color(white: 0.15), Color(white: 0.08)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                } else if let error = viewModel.errorMessage {
                    Text(error).foregroundStyle(.white.opacity(0.6))
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            currentConditionsView
                            hourlyForecastCard
                            dailyForecastCard
                            weatherDetailsGrid
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("", systemImage: "xmark", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .principal) {
                    Text(viewModel.locationName)
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            viewModel.fetchWeather()
        }
    }
    
    private var currentConditionsView: some View {
        VStack(spacing: 2) {
            if let current = viewModel.current {
                Image(systemName: current.icon)
                    .font(.system(size: 60))
                    .symbolRenderingMode(.multicolor)
                    .padding(.bottom, 8)
                
                Text("\(current.temp)°")
                    .font(.system(size: 72, weight: .thin, design: .rounded))
                    .foregroundStyle(.white)
                
                Text(current.condition)
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.7))
                
                Text("H:\(current.high)° L:\(current.low)°")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.vertical, 20)
    }
    
    private var hourlyForecastCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("HOURLY FORECAST", systemImage: "clock")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.5))
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.hourlyForecast) { hour in
                        VStack(spacing: 6) {
                            Text(hour.date.formatted(.dateTime.hour()))
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.6))
                            
                            Image(systemName: hour.icon)
                                .font(.title3)
                                .symbolRenderingMode(.multicolor)
                            
                            if hour.precipitation > 0 {
                                Text("\(hour.precipitation)%")
                                    .font(.caption2)
                                    .foregroundStyle(.cyan)
                            } else {
                                Text(" ")
                                    .font(.caption2)
                            }
                            
                            Text("\(hour.temp)°")
                                .font(.callout.weight(.medium))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 50)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }
    
    private var dailyForecastCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("7-DAY FORECAST", systemImage: "calendar")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.5))
            
            ForEach(viewModel.dailyForecast) { day in
                HStack(spacing: 8) {
                    Text(day.date.formatted(.dateTime.weekday(.abbreviated)))
                        .font(.callout)
                        .foregroundStyle(.white)
                        .frame(width: 36, alignment: .leading)
                    
                    Image(systemName: day.icon)
                        .symbolRenderingMode(.multicolor)
                        .frame(width: 28)
                    
                    if day.precipitation > 0 {
                        Text("\(day.precipitation)%")
                            .font(.caption2)
                            .foregroundStyle(.cyan)
                            .frame(width: 30)
                    } else {
                        Spacer().frame(width: 30)
                    }
                    
                    Text("\(day.low)°")
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(width: 30)
                    
                    temperatureBar(low: day.low, high: day.high, minTemp: viewModel.minTemp, maxTemp: viewModel.maxTemp)
                    
                    Text("\(day.high)°")
                        .font(.callout)
                        .foregroundStyle(.white)
                        .frame(width: 30)
                }
                .padding(.vertical, 4)
                
                if day.id != viewModel.dailyForecast.last?.id {
                    Divider().background(.white.opacity(0.1))
                }
            }
        }
        .padding()
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }
    
    private func temperatureBar(low: Int, high: Int, minTemp: Int, maxTemp: Int) -> some View {
        GeometryReader { geo in
            let range = max(maxTemp - minTemp, 1)
            let lowOffset = CGFloat(low - minTemp) / CGFloat(range)
            let highOffset = CGFloat(high - minTemp) / CGFloat(range)
            
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.15))
                
                Capsule()
                    .fill(LinearGradient(colors: [.cyan, .yellow], startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * (highOffset - lowOffset))
                    .offset(x: geo.size.width * lowOffset)
            }
        }
        .frame(height: 5)
    }
    
    private var weatherDetailsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            if let current = viewModel.current {
                detailCard(icon: "thermometer.medium", title: "FEELS LIKE", value: "\(current.feelsLike)°")
                detailCard(icon: "humidity", title: "HUMIDITY", value: "\(current.humidity)%")
                detailCard(icon: "wind", title: "WIND", value: "\(current.windSpeed) mph")
                detailCard(icon: "sun.max", title: "UV INDEX", value: "\(current.uvIndex)")
                detailCard(icon: "eye", title: "VISIBILITY", value: "\(current.visibility) mi")
                detailCard(icon: "gauge.medium", title: "PRESSURE", value: "\(current.pressure) hPa")
            }
        }
    }
    
    private func detailCard(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(0.5))
            
            Text(value)
                .font(.title2.weight(.medium))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Open-Meteo API Response

private struct OpenMeteoResponse: Codable {
    let current: Current?
    let hourly: Hourly
    let daily: Daily?
    
    struct Current: Codable {
        let temperature_2m: Double
        let apparent_temperature: Double
        let weather_code: Int
        let relative_humidity_2m: Int
        let wind_speed_10m: Double
        let surface_pressure: Double
    }
    
    struct Hourly: Codable {
        let time: [String]
        let temperature_2m: [Double]
        let weather_code: [Int]
        let precipitation_probability: [Int]
    }
    
    struct Daily: Codable {
        let time: [String]
        let temperature_2m_max: [Double]
        let temperature_2m_min: [Double]
        let weather_code: [Int]
        let precipitation_probability_max: [Int]
        let uv_index_max: [Double]
    }
}

// MARK: - Weather Detail ViewModel

@MainActor
private final class WeatherDetailViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var locationName = "Loading..."
    @Published var current: CurrentWeatherData?
    @Published var hourlyForecast: [HourlyForecast] = []
    @Published var dailyForecast: [DailyForecast] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    var minTemp: Int { dailyForecast.map(\.low).min() ?? 0 }
    var maxTemp: Int { dailyForecast.map(\.high).max() ?? 100 }
    
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }
    
    func fetchWeather() {
        isLoading = true
        errorMessage = nil
        
        let status = locationManager.authorizationStatus
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        default:
            errorMessage = "Location access required"
            isLoading = false
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        
        _Concurrency.Task {
            // Get location name
            if let placemark = try? await geocoder.reverseGeocodeLocation(location).first {
                locationName = placemark.locality ?? placemark.name ?? "Unknown"
            }
            
            await loadWeather(for: location)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = "Unable to get location"
        isLoading = false
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse ||
           manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }
    
    private func loadWeather(for location: CLLocation) async {
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,apparent_temperature,weather_code,relative_humidity_2m,wind_speed_10m,surface_pressure&hourly=temperature_2m,weather_code,precipitation_probability&daily=temperature_2m_max,temperature_2m_min,weather_code,precipitation_probability_max,uv_index_max&temperature_unit=fahrenheit&wind_speed_unit=mph&forecast_days=7"
        
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
            
            // Parse current
            if let curr = response.current, let daily = response.daily, !daily.temperature_2m_max.isEmpty {
                current = CurrentWeatherData(
                    temp: Int(curr.temperature_2m),
                    feelsLike: Int(curr.apparent_temperature),
                    condition: weatherCondition(for: curr.weather_code),
                    icon: weatherIcon(for: curr.weather_code),
                    high: Int(daily.temperature_2m_max[0]),
                    low: Int(daily.temperature_2m_min[0]),
                    humidity: curr.relative_humidity_2m,
                    windSpeed: Int(curr.wind_speed_10m),
                    uvIndex: Int(daily.uv_index_max[0]),
                    visibility: 10,
                    pressure: Int(curr.surface_pressure)
                )
            }
            
            // Parse hourly
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
            
            var forecasts: [HourlyForecast] = []
            let now = Date()
            
            for (index, timeString) in response.hourly.time.enumerated() {
                if let date = formatter.date(from: timeString + ":00"), date >= now {
                    forecasts.append(HourlyForecast(
                        date: date,
                        temp: Int(response.hourly.temperature_2m[index]),
                        icon: weatherIcon(for: response.hourly.weather_code[index]),
                        precipitation: response.hourly.precipitation_probability[index]
                    ))
                }
            }
            hourlyForecast = Array(forecasts.prefix(24))
            
            // Parse daily
            if let daily = response.daily {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                
                dailyForecast = daily.time.enumerated().compactMap { index, dateString in
                    guard let date = dateFormatter.date(from: dateString) else { return nil }
                    return DailyForecast(
                        date: date,
                        high: Int(daily.temperature_2m_max[index]),
                        low: Int(daily.temperature_2m_min[index]),
                        icon: weatherIcon(for: daily.weather_code[index]),
                        precipitation: daily.precipitation_probability_max[index]
                    )
                }
            }
            
            isLoading = false
        } catch {
            print("Open-Meteo error: \(error)")
            errorMessage = "Unable to load forecast"
            isLoading = false
        }
    }
    
    private func weatherIcon(for code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1, 2, 3: return "cloud.sun.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55: return "cloud.drizzle.fill"
        case 56, 57: return "cloud.sleet.fill"
        case 61, 63, 65: return "cloud.rain.fill"
        case 66, 67: return "cloud.sleet.fill"
        case 71, 73, 75: return "cloud.snow.fill"
        case 77: return "cloud.snow.fill"
        case 80, 81, 82: return "cloud.heavyrain.fill"
        case 85, 86: return "cloud.snow.fill"
        case 95: return "cloud.bolt.fill"
        case 96, 99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }
    
    private func weatherCondition(for code: Int) -> String {
        switch code {
        case 0: return "Clear"
        case 1: return "Mainly Clear"
        case 2: return "Partly Cloudy"
        case 3: return "Overcast"
        case 45, 48: return "Foggy"
        case 51, 53, 55: return "Drizzle"
        case 56, 57: return "Freezing Drizzle"
        case 61, 63, 65: return "Rain"
        case 66, 67: return "Freezing Rain"
        case 71, 73, 75: return "Snow"
        case 77: return "Snow Grains"
        case 80, 81, 82: return "Rain Showers"
        case 85, 86: return "Snow Showers"
        case 95: return "Thunderstorm"
        case 96, 99: return "Thunderstorm with Hail"
        default: return "Unknown"
        }
    }
}

#Preview {
    WeatherTile(weather: .placeholder, onTap: {})
        .frame(width: 160, height: 160)
        .padding()
}
