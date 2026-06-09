import SwiftUI

struct WeatherTile: View {
    @StateObject private var service = HomeWeatherService.shared

    var body: some View {
        if service.state.isLoading {
            loadingCard
        } else if service.state.failed {
            failedCard
        } else {
            weatherCard
        }
    }

    // MARK: - Loading

    private var loadingCard: some View {
        VStack(spacing: 6) {
            ProgressView()
                .tint(Kalshi.textMuted)
                .scaleEffect(0.7)
            Text("WEATHER")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(Kalshi.textMuted)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
        .kalshiCard()
        .task { service.start() }
    }

    // MARK: - Failed

    private var failedCard: some View {
        HStack(spacing: 10) {
            Image(systemName: service.state.symbolName)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Kalshi.textMuted)
            Text(service.state.comfortText)
                .font(.system(size: 12.5, weight: .medium))
                .tracking(-0.15)
                .foregroundStyle(Kalshi.textSecondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Kalshi.cardPadH)
        .kalshiCard()
    }

    // MARK: - Main Card

    private var weatherCard: some View {
        VStack(spacing: 0) {
            // ── Header badges ──
            headerRow
                .padding(.horizontal, Kalshi.cardPadH)
                .padding(.top, 12)
                .padding(.bottom, 8)

            // ── Hero temperature + condition ──
            heroRow
                .padding(.horizontal, Kalshi.cardPadH)
                .padding(.bottom, 14)

            KalshiDivider().padding(.horizontal, Kalshi.cardPadH)

            // ── Temperature curve (the star of the show) ──
            temperatureCurve
                .padding(.top, 10)
                .padding(.bottom, 6)

            KalshiDivider().padding(.horizontal, Kalshi.cardPadH)

            // ── Stats ticker ──
            statsTickerRow
                .padding(.horizontal, Kalshi.cardPadH)
                .padding(.vertical, 10)

            KalshiDivider().padding(.horizontal, Kalshi.cardPadH)

            // ── Insight ──
            insightFooter
                .padding(.horizontal, Kalshi.cardPadH)
                .padding(.vertical, 10)
        }
        .kalshiCard()
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: 6) {
            // Condition eyebrow — colored badge
            HStack(spacing: 4) {
                Image(systemName: service.state.symbolName)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(conditionBadgeFg)
                Text(service.state.condition.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.6)
            }
            .foregroundStyle(conditionBadgeFg)
            .padding(.horizontal, 7)
            .padding(.vertical, 2.5)
            .background(conditionBadgeBg, in: Capsule())

            // Location — neutral capsule, sits right next to condition
            HStack(spacing: 2) {
                Image(systemName: "location.fill")
                    .font(.system(size: 6, weight: .semibold))
                Text(service.state.locationName.isEmpty
                     ? "HERE"
                     : service.state.locationName.uppercased())
            }
            .font(.system(size: 9, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(Kalshi.textSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Kalshi.dividerBg, in: Capsule())

            Spacer()
        }
    }

    // MARK: - Hero

    private var heroRow: some View {
        HStack(alignment: .top, spacing: 0) {
            // Left: Icon + temperature — tight coupling like a market price
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: service.state.symbolName)
                    .font(.system(size: 30, weight: .light, design: .rounded))
                    .foregroundStyle(iconColor(for: service.state.symbolName))
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(service.state.temperature)
                            .font(.system(size: 28, weight: .bold))
                            .tracking(-1.12)
                            .foregroundStyle(Kalshi.textPrimary)

                        // Trend micro-arrow (like a ticker change indicator)
                        HStack(spacing: 2) {
                            Image(systemName: tempTrendIcon)
                                .font(.system(size: 9, weight: .bold))
                            Text(tempDeltaText)
                                .font(.system(size: 10, weight: .bold))
                                .tracking(-0.1)
                        }
                        .foregroundStyle(tempTrendColor)
                    }

                    Text("CURRENT")
                        .font(.system(size: 8, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(Kalshi.textMuted)
                }
            }

            Spacer()

            // Right: Feels like — like a secondary market price
            if let feelsLike = inferFeelsLike() {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(feelsLike)
                        .font(.system(size: 16, weight: .bold))
                        .tracking(-0.32)
                        .foregroundStyle(Kalshi.textPrimary)
                    Text("FEELS LIKE")
                        .font(.system(size: 8, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(Kalshi.textMuted)
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Temperature Curve (Kalshi-style sparkline)

    private var temperatureCurve: some View {
        let hourly = service.state.hourly
        let temps = hourly.compactMap { extractTemp($0.temperature) }
        let precipChances = hourly.map(\.precipitationChance)
        let hours = hourly.map(\.hour)
        let nowIndex = hourly.firstIndex(where: \.isNow) ?? 0

        return VStack(spacing: 0) {
            // Sparkline chart area
            GeometryReader { geo in
                let insetX: CGFloat = Kalshi.cardPadH + 6  // extra breathing room from card edges
                let w = geo.size.width - (insetX * 2)
                let h: CGFloat = 60
                let origin = CGPoint(x: insetX, y: 0)

                ZStack(alignment: .topLeading) {
                    // ── Precipitation bars (background layer) ──
                    precipitationBars(
                        chances: precipChances,
                        width: w, height: h, origin: origin
                    )

                    // ── Temperature curve ──
                    if temps.count >= 2 {
                        let points = curvePoints(
                            data: temps, width: w, height: h, origin: origin
                        )

                        // Gradient fill under curve
                        curveFillPath(points: points, width: w, height: h, origin: origin)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        curveLineColor.opacity(0.12),
                                        curveLineColor.opacity(0.03),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                        // The line itself
                        curveLinePath(points: points)
                            .stroke(
                                curveLineColor,
                                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                            )

                        // "NOW" marker dot — pulsing like a live market indicator
                        if nowIndex < points.count {
                            let nowPt = points[nowIndex]

                            // Outer glow ring
                            Circle()
                                .fill(curveLineColor.opacity(0.12))
                                .frame(width: 14, height: 14)
                                .position(nowPt)

                            // Middle ring
                            Circle()
                                .stroke(Kalshi.bg, lineWidth: 1.5)
                                .frame(width: 7, height: 7)
                                .position(nowPt)

                            // Inner dot
                            Circle()
                                .fill(curveLineColor)
                                .frame(width: 5, height: 5)
                                .position(nowPt)
                        }

                        // End dot (last data point)
                        if let last = points.last, nowIndex != points.count - 1 {
                            Circle()
                                .fill(curveLineColor.opacity(0.25))
                                .frame(width: 4, height: 4)
                                .position(last)
                        }
                    }
                }
                .frame(height: h)
            }
            .frame(height: 60)

            // ── Hour labels (X-axis) ──
            hourLabels(hours: hours, nowIndex: nowIndex)
                .padding(.top, 6)
                .padding(.horizontal, Kalshi.cardPadH)
        }
    }

    // Precipitation as subtle blue columns from the bottom
    private func precipitationBars(
        chances: [Double], width: CGFloat, height: CGFloat, origin: CGPoint
    ) -> some View {
        Canvas { ctx, size in
            guard chances.count >= 2 else { return }
            let stepX = width / CGFloat(chances.count - 1)
            let barW: CGFloat = max(2, stepX * 0.35)

            for (i, chance) in chances.enumerated() where chance > 0.2 {
                let x = origin.x + stepX * CGFloat(i)
                let barH = height * CGFloat(min(chance, 1.0)) * 0.4
                let rect = CGRect(
                    x: x - barW / 2,
                    y: height - barH,
                    width: barW,
                    height: barH
                )
                let path = Path(roundedRect: rect, cornerRadius: 1)
                ctx.fill(
                    path,
                    with: .color(Kalshi.blue.opacity(0.08 + chance * 0.12))
                )
            }
        }
    }

    // Hour labels along the bottom like X-axis tick labels
    private func hourLabels(hours: [String], nowIndex: Int) -> some View {
        // Show every other label to avoid crowding, always show "Now"
        HStack(spacing: 0) {
            ForEach(hours.indices, id: \.self) { i in
                let show = i == nowIndex || i % 3 == 0
                Text(show ? hours[i].uppercased() : "")
                    .font(.system(size: 8, weight: i == nowIndex ? .bold : .medium))
                    .tracking(0.3)
                    .foregroundStyle(
                        i == nowIndex ? Kalshi.textPrimary : Kalshi.textMuted
                    )
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Curve Geometry

    private func curvePoints(
        data: [Double], width: CGFloat, height: CGFloat, origin: CGPoint
    ) -> [CGPoint] {
        guard data.count >= 2 else { return [] }
        let minVal = data.min() ?? 0
        let maxVal = data.max() ?? 100
        let range = max(maxVal - minVal, 1)
        let insetY: CGFloat = 8

        return data.enumerated().map { i, val in
            let x = origin.x + width * CGFloat(i) / CGFloat(data.count - 1)
            let normalized = CGFloat((val - minVal) / range)
            let y = insetY + (height - insetY * 2) * (1 - normalized)
            return CGPoint(x: x, y: y)
        }
    }

    private func curveLinePath(points: [CGPoint]) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            for i in 1..<points.count {
                let p0 = points[max(0, i - 2)]
                let p1 = points[i - 1]
                let p2 = points[i]
                let p3 = points[min(points.count - 1, i + 1)]
                let cp1 = CGPoint(
                    x: p1.x + (p2.x - p0.x) / 6,
                    y: p1.y + (p2.y - p0.y) / 6
                )
                let cp2 = CGPoint(
                    x: p2.x - (p3.x - p1.x) / 6,
                    y: p2.y - (p3.y - p1.y) / 6
                )
                path.addCurve(to: p2, control1: cp1, control2: cp2)
            }
        }
    }

    private func curveFillPath(
        points: [CGPoint], width: CGFloat, height: CGFloat, origin: CGPoint
    ) -> Path {
        var fill = curveLinePath(points: points)
        fill.addLine(to: CGPoint(x: origin.x + width, y: height))
        fill.addLine(to: CGPoint(x: origin.x, y: height))
        fill.closeSubpath()
        return fill
    }

    // The curve color adapts to temperature trend — like Kalshi green/red for up/down markets
    private var curveLineColor: Color {
        let temps = service.state.hourly.prefix(6).compactMap { extractTemp($0.temperature) }
        guard temps.count >= 2 else { return Kalshi.blue }
        let delta = (temps.last ?? 0) - (temps.first ?? 0)
        if delta > 3 { return Kalshi.red }       // warming → red (bearish comfort)
        if delta < -3 { return Kalshi.blue }      // cooling → blue
        return Kalshi.green                        // stable → green (bullish comfort)
    }

    // MARK: - Stats Ticker Row (compact, dense)

    private var statsTickerRow: some View {
        let temps = service.state.hourly.compactMap { extractTemp($0.temperature) }
        let hi = temps.max().map { "\(Int($0))°" } ?? "--"
        let lo = temps.min().map { "\(Int($0))°" } ?? "--"
        let maxPrecip = service.state.hourly.map(\.precipitationChance).max() ?? 0
        let spread = (temps.max() ?? 0) - (temps.min() ?? 0)

        return HStack(spacing: 0) {
            tickerCell(label: "H", value: hi, color: Kalshi.red)
            tickerDivider
            tickerCell(label: "L", value: lo, color: Kalshi.blue)
            tickerDivider
            tickerCell(
                label: "RAIN",
                value: "\(Int(maxPrecip * 100))%",
                color: rainStatColor(maxPrecip)
            )
            tickerDivider
            tickerCell(
                label: "RNG",
                value: "\(Int(spread))°",
                color: Kalshi.amber
            )
        }
    }

    private func tickerCell(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(Kalshi.textMuted)

            Text(value)
                .font(.system(size: 13, weight: .bold))
                .tracking(-0.26)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    private var tickerDivider: some View {
        Rectangle()
            .fill(Kalshi.cardBorder)
            .frame(width: 0.5, height: 18)
    }

    // MARK: - Insight Footer

    private var insightFooter: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(insightDotColor)
                .frame(width: 4, height: 4)

            Text(service.state.comfortText)
                .font(.system(size: 11.5, weight: .medium))
                .tracking(-0.12)
                .foregroundStyle(Kalshi.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Helpers

    private func extractTemp(_ str: String) -> Double {
        let digits = str.filter { $0.isNumber || $0 == "." || $0 == "-" }
        return Double(digits) ?? 0
    }

    private func inferFeelsLike() -> String? {
        guard !service.state.temperature.isEmpty,
              service.state.temperature != "--" else { return nil }
        return service.state.temperature
    }

    // MARK: - Color System

    private func iconColor(for symbol: String) -> Color {
        if symbol.contains("sun.max") {
            return Color(red: 0.99, green: 0.72, blue: 0.07)
        }
        if symbol.contains("sun") || symbol.contains("cloud.sun") {
            return Color(red: 0.98, green: 0.78, blue: 0.20)
        }
        if symbol.contains("moon.stars") {
            return Color(red: 0.42, green: 0.35, blue: 0.80)
        }
        if symbol.contains("moon") {
            return Color(red: 0.55, green: 0.50, blue: 0.85)
        }
        if symbol.contains("heavyrain") {
            return Color(red: 0.15, green: 0.40, blue: 0.85)
        }
        if symbol.contains("rain") || symbol.contains("drizzle") {
            return Kalshi.blue
        }
        if symbol.contains("snow") {
            return Color(red: 0.58, green: 0.78, blue: 0.99)
        }
        if symbol.contains("bolt") {
            return Kalshi.amber
        }
        if symbol.contains("fog") {
            return Color(red: 0.70, green: 0.70, blue: 0.75)
        }
        if symbol.contains("cloud") {
            return Kalshi.textSecondary
        }
        return Kalshi.textMuted
    }

    private func rainStatColor(_ precip: Double) -> Color {
        if precip > 0.6 { return Kalshi.blue }
        if precip > 0.3 { return Color(red: 0.58, green: 0.78, blue: 0.99) }
        return Kalshi.textSecondary
    }

    private var insightDotColor: Color {
        let maxPrecip = service.state.hourly.map(\.precipitationChance).max() ?? 0
        if maxPrecip > 0.6 { return Kalshi.blue }
        if maxPrecip > 0.3 { return Kalshi.amber }
        return Kalshi.green
    }

    // MARK: - Condition Badge

    private var conditionBadgeBg: Color {
        let s = service.state.symbolName
        if s.contains("sun")  { return Color(red: 0.99, green: 0.95, blue: 0.82) }
        if s.contains("rain") || s.contains("drizzle") { return Color(red: 0.87, green: 0.93, blue: 1.0) }
        if s.contains("snow") { return Color(red: 0.90, green: 0.94, blue: 1.0) }
        if s.contains("bolt") { return Color(red: 1.0, green: 0.96, blue: 0.85) }
        if s.contains("fog")  { return Color(red: 0.94, green: 0.94, blue: 0.96) }
        if s.contains("moon") { return Color(red: 0.92, green: 0.90, blue: 0.98) }
        return Kalshi.dividerBg
    }

    private var conditionBadgeFg: Color {
        let s = service.state.symbolName
        if s.contains("sun")  { return Color(red: 0.75, green: 0.55, blue: 0.05) }
        if s.contains("rain") || s.contains("drizzle") { return Color(red: 0.15, green: 0.40, blue: 0.85) }
        if s.contains("snow") { return Color(red: 0.30, green: 0.50, blue: 0.80) }
        if s.contains("bolt") { return Color(red: 0.70, green: 0.50, blue: 0.05) }
        if s.contains("fog")  { return Color(red: 0.50, green: 0.50, blue: 0.55) }
        if s.contains("moon") { return Color(red: 0.40, green: 0.30, blue: 0.70) }
        return Kalshi.textSecondary
    }

    // MARK: - Temperature Trend

    private var tempTrendIcon: String {
        let temps = service.state.hourly.prefix(4).compactMap { extractTemp($0.temperature) }
        guard temps.count >= 2 else { return "arrow.right" }
        let delta = temps.last! - temps.first!
        if delta > 2 { return "arrow.up.right" }
        if delta < -2 { return "arrow.down.right" }
        return "arrow.right"
    }

    private var tempTrendColor: Color {
        let temps = service.state.hourly.prefix(4).compactMap { extractTemp($0.temperature) }
        guard temps.count >= 2 else { return Kalshi.textMuted }
        let delta = temps.last! - temps.first!
        if delta > 2 { return Kalshi.red }
        if delta < -2 { return Kalshi.blue }
        return Kalshi.textMuted
    }

    private var tempDeltaText: String {
        let temps = service.state.hourly.prefix(4).compactMap { extractTemp($0.temperature) }
        guard temps.count >= 2 else { return "" }
        let delta = abs(temps.last! - temps.first!)
        if delta > 1 { return "\(Int(delta))°" }
        return ""
    }
}

#Preview {
    ZStack {
        Kalshi.bg.ignoresSafeArea()
        WeatherTile()
            .padding(.horizontal, 16)
    }
}
