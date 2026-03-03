import SwiftUI

struct WeatherTile: View {
    @StateObject private var service = HomeWeatherService.shared

    private var palette: WeatherPalette {
        WeatherPalette.resolve(symbol: service.state.symbolName)
    }

    var body: some View {
        if service.state.isLoading {
            loadingCard
        } else {
            weatherCard
        }
    }

    // MARK: - Loading

    private var loadingCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.tertiarySystemFill))
            HStack(spacing: 8) {
                ProgressView().tint(.secondary).scaleEffect(0.8)
                Text("Weather")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 140)
        .task { service.start() }
    }

    // MARK: - Card

    private var weatherCard: some View {
        VStack(spacing: 0) {
            heroSection
            forecastStrip
            insightBar
        }
        .background {
            ZStack {
                palette.gradient

                // Top-right glow
                Ellipse()
                    .fill(palette.glow.opacity(0.25))
                    .frame(width: 160, height: 120)
                    .blur(radius: 50)
                    .offset(x: 80, y: -30)

                // Subtle vignette bottom
                LinearGradient(
                    colors: [.clear, .black.opacity(0.18)],
                    startPoint: .center,
                    endPoint: .bottom
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
        )
    }

    // MARK: - Hero

    private var heroSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 3) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 8))
                    Text(service.state.locationName.isEmpty
                         ? "Current Location"
                         : service.state.locationName)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.65))

                Text(service.state.temperature)
                    .font(.system(size: 40, weight: .thin, design: .rounded))
                    .foregroundStyle(.white)

                Text(service.state.condition)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
            }

            Spacer()

            Image(systemName: service.state.symbolName)
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 38, weight: .light))
                .shadow(color: palette.glow.opacity(0.4), radius: 12, y: 2)
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Forecast Strip

    private var forecastStrip: some View {
        VStack(spacing: 0) {
            separator
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(service.state.hourly) { slot in
                        ForecastCell(slot: slot, accent: palette.accent)
                    }
                }
                .padding(.horizontal, 14)
            }
            .scrollClipDisabled()
            .padding(.vertical, 8)
        }
    }

    // MARK: - Insight

    private var insightBar: some View {
        VStack(spacing: 0) {
            separator
            Text(service.state.comfortText)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(.white.opacity(0.10))
            .frame(height: 0.5)
            .padding(.horizontal, 14)
    }
}

// MARK: - Forecast Cell

private struct ForecastCell: View {
    let slot: HourlyForecast
    let accent: Color

    var body: some View {
        VStack(spacing: 5) {
            Text(slot.hour)
                .font(.system(size: 10, weight: slot.isNow ? .bold : .regular))
                .foregroundStyle(slot.isNow ? .white : .white.opacity(0.50))

            Image(systemName: slot.symbolName)
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 14))
                .frame(height: 16)

            Text(slot.temperature)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.90))
        }
        .frame(width: 44)
        .padding(.vertical, 6)
        .background {
            if slot.isNow {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.white.opacity(0.15))
            }
        }
    }
}

// MARK: - Weather Palette

private struct WeatherPalette {
    let gradient: LinearGradient
    let glow: Color
    let accent: Color

    static func resolve(symbol: String) -> WeatherPalette {
        let hour = Calendar.current.component(.hour, from: Date())
        let isNight = hour < 6 || hour >= 20

        if symbol.contains("thunder") {
            return .init(
                gradient: LinearGradient(
                    colors: [
                        Color(red: 0.18, green: 0.10, blue: 0.35),
                        Color(red: 0.10, green: 0.06, blue: 0.22)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing),
                glow: Color(red: 0.65, green: 0.45, blue: 1.0),
                accent: Color(red: 0.75, green: 0.60, blue: 1.0)
            )
        }

        if symbol.contains("snow") || symbol.contains("sleet") {
            return .init(
                gradient: LinearGradient(
                    colors: [
                        Color(red: 0.50, green: 0.58, blue: 0.72),
                        Color(red: 0.32, green: 0.40, blue: 0.58)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing),
                glow: .white,
                accent: Color(red: 0.75, green: 0.88, blue: 1.0)
            )
        }

        if symbol.contains("rain") || symbol.contains("drizzle") {
            return .init(
                gradient: LinearGradient(
                    colors: [
                        Color(red: 0.16, green: 0.24, blue: 0.40),
                        Color(red: 0.08, green: 0.14, blue: 0.28)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing),
                glow: Color(red: 0.35, green: 0.55, blue: 0.90),
                accent: Color(red: 0.45, green: 0.70, blue: 1.0)
            )
        }

        if isNight {
            return .init(
                gradient: LinearGradient(
                    colors: [
                        Color(red: 0.06, green: 0.06, blue: 0.18),
                        Color(red: 0.03, green: 0.03, blue: 0.12)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing),
                glow: Color(red: 0.40, green: 0.35, blue: 0.85),
                accent: Color(red: 0.60, green: 0.55, blue: 1.0)
            )
        }

        if symbol.contains("cloud") {
            return .init(
                gradient: LinearGradient(
                    colors: [
                        Color(red: 0.32, green: 0.42, blue: 0.58),
                        Color(red: 0.20, green: 0.28, blue: 0.44)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing),
                glow: Color(red: 0.55, green: 0.70, blue: 0.95),
                accent: Color(red: 0.60, green: 0.78, blue: 1.0)
            )
        }

        // Clear / sunny
        return .init(
            gradient: LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.40, blue: 0.78),
                    Color(red: 0.05, green: 0.22, blue: 0.55)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing),
            glow: Color(red: 1.0, green: 0.88, blue: 0.40),
            accent: Color(red: 0.95, green: 0.80, blue: 0.30)
        )
    }
}

#Preview {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        WeatherTile()
            .padding(.horizontal, 20)
    }
}
