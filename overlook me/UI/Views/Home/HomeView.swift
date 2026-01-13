import SwiftUI
import Combine
import WeatherKit
import CoreLocation
import Security
import UIKit

struct HomeView: View {
    @Binding var path: NavigationPath
    @EnvironmentObject private var tabBar: TabBarStyleStore
    @State private var isDetentSheetPresented = false
    
    var body: some View {
        NavigationStack(path: $path) {
            rootView
                .navigationDestination(for: SideNavRoute.self) { route in
                    destination(for: route)
                }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
    
    @ViewBuilder
    private var rootView: some View {
        if tabBar.config == .dailyHabits {
            DailyHabitsView()
                .tabBarConfig(.dailyHabits)
                .toolbar(.visible, for: .navigationBar)
                .id("dailyHabits")
        } else {
            landingView
                .tabBarConfig(.default)
                .toolbar(.hidden, for: .navigationBar)
                .id("landing")
        }
    }
    
    private var landingView: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                TimeOfDayGreetingContainer(onArrowTap: {
                    isDetentSheetPresented = true
                })
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 70)  // Manual padding: status bar (~47) + spacing (23)
            .padding(.bottom, 24)
            .safeAreaPadding(.top, 0)
        }
        .ignoresSafeArea(edges: .top)
        .sheet(isPresented: $isDetentSheetPresented) {
            DetentBottomSheetView()
        }
    }
    
    @ViewBuilder
    private func destination(for route: SideNavRoute) -> some View {
        switch route {
        case .homeDashboard:
            landingView
                .tabBarConfig(.default)
                .toolbar(.hidden, for: .navigationBar)
            
        case .financeDashboard:
            FinanceDashboardView()
                .tabBarConfig(.finance)
                .toolbar(.visible, for: .navigationBar)
        case .bankAccounts:
            BankAccountsView()
                .tabBarConfig(.finance)
                .toolbar(.visible, for: .navigationBar)
        case .transactions:
            TransactionsView()
                .tabBarConfig(.finance)
                .toolbar(.visible, for: .navigationBar)
        case .budgets:
            BudgetsView()
                .tabBarConfig(.finance)
                .toolbar(.visible, for: .navigationBar)
        case .insights:
            InsightsView()
                .tabBarConfig(.finance)
                .toolbar(.visible, for: .navigationBar)
        case .netWorth:
            NetWorthView()
                .tabBarConfig(.finance)
                .toolbar(.visible, for: .navigationBar)
            
        case .productivityDashboard:
            ProductivityDashboardView()
                .tabBarConfig(.productivity)
                .toolbar(.visible, for: .navigationBar)
        case .tasks:
            TasksView()
                .tabBarConfig(.productivity)
                .toolbar(.visible, for: .navigationBar)
        case .dailyHabits:
            // Note: dailyHabits is handled via tabBar.config switch in MainContainerView
            // This destination should not be reached, but kept for safety
            EmptyView()
        case .checklists:
            ChecklistsView()
                .tabBarConfig(.productivity)
                .toolbar(.visible, for: .navigationBar)
            
        case .managePlan:
            ManagePlanView()
                .tabBarConfig(.subscriptions)
                .toolbar(.visible, for: .navigationBar)
        }
    }
}

// MARK: - Greeting Presentation

private struct TimeOfDayGreetingContainer: View {
    let onArrowTap: () -> Void
    private let now = Date()
    
    var body: some View {
        TimelineView(.periodic(from: now, by: 60)) { context in
            let greeting = TimeOfDayGreeting(date: context.date)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    Text(greeting.salutation)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Button(action: onArrowTap) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Show details")
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(red: 49 / 255, green: 7 / 255, blue: 89 / 255))
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(greeting.salutation)
        }
    }
}

private struct TimeOfDayGreeting {
    let salutation: String
    
    init(date: Date) {
        let components = Calendar.current.dateComponents([.hour], from: date)
        let hour = components.hour ?? 0
        
        switch hour {
        case 5..<12:
            salutation = "Good Morning"
        case 12..<17:
            salutation = "Good Afternoon"
        case 17..<22:
            salutation = "Good Evening"
        default:
            salutation = "Sweet Night"
        }
    }
}

private struct DetentBottomSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var weatherModel = WeatherTileViewModel()
    
    var body: some View {
        ZStack(alignment: .top) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(alignment: .top, spacing: 16) {
                        WeatherOverviewTile(
                            snapshot: weatherModel.snapshot,
                            onRefresh: { weatherModel.refresh() },
                            onTroubleshoot: { }
                        )
                        .frame(maxWidth: 360)
                        
                        Spacer(minLength: 0)
                    }
                    
                    Text("Hook up real data here to mirror the productivity overview experience.")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
                .padding(.horizontal, 24)
                .padding(.top, 120)
                .padding(.bottom, 48)
            }
            .scrollBounceBehavior(.basedOnSize)
            .task { weatherModel.startIfNeeded() }
            
            HStack(spacing: 12) {
                Text("Today's Overview")
                    .font(.title2.bold())
                
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close overview")
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 12)
            .background(
                Rectangle()
                    .fill(.regularMaterial)
                    .mask(
                        LinearGradient(
                            colors: [Color.white, Color.white.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
        }
    }
}

// MARK: - WeatherKit Diagnostics

private struct WeatherKitDiagnostics {
    static func hasWeatherKitEntitlement() -> Bool {
        // Check if the entitlement exists in the app
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "weatherkit.check",
            kSecReturnData as String: false
        ]
        
        // Try to check app's entitlements
        if let entitlements = Bundle.main.object(forInfoDictionaryKey: "com.apple.developer.weatherkit") {
            return entitlements is Bool || entitlements is NSNumber
        }
        
        // Alternative check via entitlements file
        let hasCapability = Bundle.main.object(forInfoDictionaryKey: "WeatherKit") != nil
        return hasCapability
    }
    
    static func getDetailedInfo() -> String {
        let bundleId = Bundle.main.bundleIdentifier ?? "<unknown>"
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "<unknown>"
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let osString = "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
        
        let isSimulator: Bool = {
            #if targetEnvironment(simulator)
            return true
            #else
            return false
            #endif
        }()
        
        let deviceModel = UIDevice.current.model
        let systemVersion = UIDevice.current.systemVersion
        
        return """
        === App Info ===
        Name: \(appName)
        Bundle ID: \(bundleId)
        Version: \(version) (\(build))
        
        === Device ===
        Model: \(deviceModel)
        System: iOS \(systemVersion)
        OS Version: \(osString)
        Simulator: \(isSimulator)
        
        === Capabilities ===
        WeatherKit Entitlement: \(hasWeatherKitEntitlement())
        
        === Common Issues ===
        1. WeatherKit NOT enabled in Apple Developer Portal
           → Go to developer.apple.com → Identifiers
           → Find "\(bundleId)"
           → Enable WeatherKit capability
        
        2. Provisioning Profile missing capability
           → Xcode → Signing & Capabilities
           → Ensure "WeatherKit" is in list
           → Try "Clean Build Folder" & rebuild
        
        3. Running on Simulator
           → Requires valid provisioning profile
           → Try on physical device instead
        
        4. Team/Certificate issues
           → Check Signing & Capabilities tab
           → Try different signing team
           → Regenerate provisioning profiles
        """
    }
}

// MARK: - Weather Tile

private struct WeatherOverviewTile: View {
    let snapshot: WeatherSnapshot
    let onRefresh: () -> Void
    let onTroubleshoot: (() -> Void)?

    @State private var showDiagnostics = false
    @State private var diagnosticsText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onRefresh) {
                Label(snapshot.locationName, systemImage: "location.fill")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            .buttonStyle(.glass)
            .tint(.purple)
            .accessibilityLabel("Refresh weather for \(snapshot.locationName)")
            
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: snapshot.symbolName)
                    .font(.system(size: 42))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(snapshot.temperature)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.8)
                    
                    Text(snapshot.condition)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                }
            }
            
            Text(snapshot.statusMessage ?? "Now")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
            
            Text("H \(snapshot.high)  L \(snapshot.low)")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.2))
                )
                .foregroundStyle(.white)

            #if DEBUG
            Divider()
            HStack(spacing: 8) {
                Button("Troubleshoot") {
                    prepareDiagnostics()
                    showDiagnostics = true
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.bordered)
                
                if let onTroubleshoot {
                    Button("Test Fetch") { onTroubleshoot() }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.bordered)
                }
            }
            .alert("Weather Diagnostics", isPresented: $showDiagnostics) {
                Button("Copy All") { 
                    UIPasteboard.general.string = diagnosticsText 
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text(diagnosticsText)
            }
            #endif
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(red: 34 / 255, green: 7 / 255, blue: 68 / 255))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .overlay(alignment: .topTrailing) {
            if snapshot.isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .padding(12)
            }
        }
    }

    private func prepareDiagnostics() {
        let bundleId = Bundle.main.bundleIdentifier ?? "<unknown>"
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let osString = "iOS \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
        let hasEntitlement = WeatherKitDiagnostics.hasWeatherKitEntitlement()

        let statusLabel: String = {
            let status = CLLocationManager().authorizationStatus
            switch status {
            case .notDetermined: return "notDetermined"
            case .restricted: return "restricted"
            case .denied: return "denied"
            case .authorizedAlways: return "authorizedAlways"
            case .authorizedWhenInUse: return "authorizedWhenInUse"
            @unknown default: return "unknown"
            }
        }()

        let requires16 = ProcessInfo.processInfo.isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: 16, minorVersion: 0, patchVersion: 0))
        
        let isSimulator: Bool = {
            #if targetEnvironment(simulator)
            return true
            #else
            return false
            #endif
        }()
        
        let errorInfo: String = {
            if snapshot.statusMessage?.contains("Unable") == true || 
               snapshot.statusMessage?.contains("unavailable") == true {
                return "\nLast Error: \(snapshot.statusMessage ?? "Unknown")"
            }
            return ""
        }()

        diagnosticsText = """
        === WeatherKit Diagnostics ===
        
        📱 Device Info:
        • Bundle: \(bundleId)
        • OS: \(osString)
        • Simulator: \(isSimulator)
        
        🔐 Capabilities:
        • WeatherKit Entitlement: \(hasEntitlement ? "✅" : "❌")
        • Location Auth: \(statusLabel)
        • iOS 16+ Required: \(requires16 ? "✅" : "❌")
        \(errorInfo)
        
        ⚠️ If WeatherKit fails (Error Code 2):
        
        1️⃣ Apple Developer Portal:
           • Visit: developer.apple.com/account
           • Go to: Identifiers → App IDs
           • Find: "\(bundleId)"
           • Enable: WeatherKit capability
           • Save changes
        
        2️⃣ Xcode Project:
           • Open: Signing & Capabilities tab
           • Verify: "WeatherKit" capability exists
           • Clean: Cmd+Shift+K
           • Rebuild project
        
        3️⃣ Provisioning:
           • Delete app from device/simulator
           • In Xcode: Product → Clean Build Folder
           • Rebuild & reinstall
        
        4️⃣ Physical Device:
           • Simulators may have issues
           • Try on real iPhone/iPad
        
        5️⃣ Sign In:
           • Ensure device/simulator signed into iCloud
           • Settings → Apple ID
        """
    }
}

@MainActor
private final class WeatherTileViewModel: NSObject, ObservableObject {
    @Published private(set) var snapshot: WeatherSnapshot = .placeholder
    
    private let weatherService = WeatherService.shared
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var hasStarted = false
    
    #if DEBUG
    @Published var lastError: Error?
    @Published var lastErrorDetails: String = ""
    #endif
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }
    
    func startIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true
        
        #if DEBUG
        print("🚀 Starting WeatherTileViewModel...")
        print("   Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
        print("   iOS Version: \(UIDevice.current.systemVersion)")
        #endif
        
        requestAuthorization()
    }
    
    func refresh() {
        #if DEBUG
        print("🔄 Refresh requested by user")
        #endif
        
        snapshot = snapshot.updating()
        locationManager.requestLocation()
    }

    #if DEBUG
    func debugRunFixedFetch() {
        snapshot = snapshot.updating()
        handle(location: CLLocation(latitude: 37.3349, longitude: -122.0090))
    }
    #endif
    
    private func requestAuthorization() {
        let status = locationManager.authorizationStatus
        
        #if DEBUG
        let statusString: String = {
            switch status {
            case .notDetermined: return "notDetermined"
            case .restricted: return "restricted"
            case .denied: return "denied"
            case .authorizedAlways: return "authorizedAlways"
            case .authorizedWhenInUse: return "authorizedWhenInUse"
            @unknown default: return "unknown"
            }
        }()
        print("🔑 Requesting authorization. Current status: \(statusString)")
        #endif
        
        switch status {
        case .notDetermined:
            #if DEBUG
            print("📱 Requesting 'When In Use' authorization...")
            #endif
            locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            #if DEBUG
            print("⚠️ Location access restricted or denied")
            #endif
            snapshot = .denied
        default:
            #if DEBUG
            print("✅ Location authorized, requesting location...")
            #endif
            locationManager.requestLocation()
        }
    }
    
    private func handle(location: CLLocation) {
        #if DEBUG
        print("📍 Location received:")
        print("   Latitude: \(location.coordinate.latitude)")
        print("   Longitude: \(location.coordinate.longitude)")
        print("   Accuracy: \(location.horizontalAccuracy)m")
        print("   Timestamp: \(location.timestamp)")
        #endif
        
        Task {
            await fetchWeather(for: location)
        }
    }
    
    private func fetchWeather(for location: CLLocation) async {
        #if DEBUG
        print("🌤️ Fetching weather for location...")
        print("   Coordinates: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        #endif
        
        do {
            let weather = try await weatherService.weather(for: location)
            
            #if DEBUG
            print("✅ Weather data received!")
            print("   Condition: \(weather.currentWeather.condition.description)")
            print("   Temperature: \(weather.currentWeather.temperature)")
            print("   Symbol: \(weather.currentWeather.symbolName)")
            print("   Humidity: \(weather.currentWeather.humidity)")
            print("   Wind Speed: \(weather.currentWeather.wind.speed)")
            if let daily = weather.dailyForecast.first {
                print("   High: \(daily.highTemperature)")
                print("   Low: \(daily.lowTemperature)")
            }
            #endif
            
            let placemark = try? await geocoder.reverseGeocodeLocation(location).first
            let locality = placemark?.locality ?? placemark?.name ?? "Current Location"
            
            #if DEBUG
            print("📍 Location name: \(locality)")
            if let placemark = placemark {
                print("   City: \(placemark.locality ?? "?")")
                print("   State: \(placemark.administrativeArea ?? "?")")
                print("   Country: \(placemark.country ?? "?")")
            }
            #endif
            
            snapshot = WeatherSnapshot(
                locationName: locality,
                condition: weather.currentWeather.condition.description.capitalized,
                temperature: weather.currentWeather.temperature.formatted(.measurement(width: .wide)),
                high: weather.dailyForecast.first?.highTemperature.formatted(.measurement(width: .narrow)) ?? "--",
                low: weather.dailyForecast.first?.lowTemperature.formatted(.measurement(width: .narrow)) ?? "--",
                symbolName: weather.currentWeather.symbolName,
                statusMessage: "Updated \(Date.now.formatted(date: .omitted, time: .shortened))",
                isLoading: false
            )
            
            #if DEBUG
            print("✅ Weather snapshot updated successfully")
            #endif
        } catch {
            let nsError = error as NSError
            
            #if DEBUG
            print("🌧️ WeatherKit fetch failed:", error)
            lastError = error
            
            lastErrorDetails = """
            Domain: \(nsError.domain)
            Code: \(nsError.code)
            Description: \(nsError.localizedDescription)
            Reason: \(nsError.localizedFailureReason ?? "none")
            Recovery: \(nsError.localizedRecoverySuggestion ?? "none")
            UserInfo: \(nsError.userInfo)
            """
            print("📊 Error Details:\n\(lastErrorDetails)")
            print("⚠️ Using mock weather data for development")
            
            // Use mock data in debug builds
            let placemark = try? await geocoder.reverseGeocodeLocation(location).first
            let locality = placemark?.locality ?? placemark?.name ?? "Cupertino"
            
            snapshot = WeatherSnapshot(
                locationName: locality,
                condition: "Partly Cloudy",
                temperature: "72°F",
                high: "75°F",
                low: "58°F",
                symbolName: "cloud.sun.fill",
                statusMessage: "Mock data (WeatherKit auth pending)",
                isLoading: false
            )
            #else
            // Check if it's a WeatherKit authentication error
            if nsError.domain == "WeatherDaemon.WDSJWTAuthenticatorServiceListener.Errors" && nsError.code == 2 {
                snapshot = .error(message: "WeatherKit setup needed. Check Apple Developer Portal.")
            } else if nsError.domain.contains("WeatherDaemon") {
                snapshot = .error(message: "WeatherKit auth failed (Code \(nsError.code))")
            } else {
                snapshot = .error(message: "Unable to load weather.")
            }
            #endif
        }
    }
}

extension WeatherTileViewModel: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        #if DEBUG
        let status = manager.authorizationStatus
        let statusString: String = {
            switch status {
            case .notDetermined: return "notDetermined"
            case .restricted: return "restricted"
            case .denied: return "denied"
            case .authorizedAlways: return "authorizedAlways"
            case .authorizedWhenInUse: return "authorizedWhenInUse"
            @unknown default: return "unknown"
            }
        }()
        print("🔐 Location authorization changed: \(statusString)")
        #endif
        
        requestAuthorization()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        #if DEBUG
        print("✅ Location manager did update locations (count: \(locations.count))")
        #endif
        
        manager.stopUpdatingLocation()
        handle(location: location)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        #if DEBUG
        print("❌ Location manager failed with error:")
        print("   Error: \(error.localizedDescription)")
        let nsError = error as NSError
        print("   Domain: \(nsError.domain)")
        print("   Code: \(nsError.code)")
        #endif
        
        snapshot = .error(message: "Location unavailable.")
    }
}

private struct WeatherSnapshot {
    let locationName: String
    let condition: String
    let temperature: String
    let high: String
    let low: String
    let symbolName: String
    let statusMessage: String?
    let isLoading: Bool
    
    static let placeholder = WeatherSnapshot(
        locationName: "Finding you…",
        condition: "Loading",
        temperature: "--",
        high: "--",
        low: "--",
        symbolName: "cloud.sun",
        statusMessage: "Allow location access",
        isLoading: true
    )
    
    static let denied = WeatherSnapshot(
        locationName: "Location Needed",
        condition: "Enable access in Settings",
        temperature: "--",
        high: "--",
        low: "--",
        symbolName: "location.slash",
        statusMessage: "Tap to retry after granting access",
        isLoading: false
    )
    
    static func error(message: String) -> WeatherSnapshot {
        WeatherSnapshot(
            locationName: "Weather Unavailable",
            condition: message,
            temperature: "--",
            high: "--",
            low: "--",
            symbolName: "exclamationmark.triangle",
            statusMessage: message,
            isLoading: false
        )
    }
    
    func updating() -> WeatherSnapshot {
        WeatherSnapshot(
            locationName: locationName,
            condition: "Updating…",
            temperature: temperature,
            high: high,
            low: low,
            symbolName: symbolName,
            statusMessage: statusMessage,
            isLoading: true
        )
    }
}
