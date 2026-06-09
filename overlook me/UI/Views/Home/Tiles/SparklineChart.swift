import SwiftUI

/// Kalshi-style line chart — mimics their prediction market price charts.
/// Features: smooth line, gradient area fill, Y-axis labels, subtle grid lines,
/// end dot with value label, and day labels on X-axis.
struct KalshiLineChart: View {
    let data: [Double]
    let labels: [String]
    var lineColor: Color = Kalshi.green
    var height: CGFloat = 100
    var showYAxis: Bool = true
    var ySteps: Int = 4

    var body: some View {
        GeometryReader { geo in
            let chartWidth = geo.size.width - (showYAxis ? 28 : 0)
            let chartHeight = geo.size.height
            let chartOrigin = CGPoint(x: showYAxis ? 28 : 0, y: 0)
            let points = normalizedPoints(
                in: CGSize(width: chartWidth, height: chartHeight),
                origin: chartOrigin
            )

            ZStack(alignment: .topLeading) {
                // ── Grid lines ──
                if showYAxis {
                    gridLines(chartOrigin: chartOrigin, chartWidth: chartWidth, chartHeight: chartHeight)
                }

                // ── Area fill ──
                if points.count >= 2 {
                    fillPath(points: points, chartOrigin: chartOrigin, chartWidth: chartWidth, chartHeight: chartHeight)
                        .fill(
                            LinearGradient(
                                colors: [
                                    lineColor.opacity(0.15),
                                    lineColor.opacity(0.03),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    // ── The line ──
                    linePath(points: points)
                        .stroke(
                            lineColor,
                            style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                        )

                    // ── End dot ──
                    if let last = points.last {
                        // Outer glow
                        Circle()
                            .fill(lineColor.opacity(0.15))
                            .frame(width: 10, height: 10)
                            .position(last)

                        // Inner dot
                        Circle()
                            .fill(lineColor)
                            .frame(width: 4, height: 4)
                            .position(last)
                    }
                }

                // ── Y-axis labels ──
                if showYAxis {
                    yAxisLabels(chartHeight: chartHeight)
                }
            }
        }
        .frame(height: height)
    }

    // MARK: - Grid

    private func gridLines(chartOrigin: CGPoint, chartWidth: CGFloat, chartHeight: CGFloat) -> some View {
        Canvas { ctx, size in
            let insetTop: CGFloat = 6
            let insetBottom: CGFloat = 6
            let drawH = chartHeight - insetTop - insetBottom

            for i in 0...ySteps {
                let y = insetTop + drawH * CGFloat(i) / CGFloat(ySteps)
                let from = CGPoint(x: chartOrigin.x, y: y)
                let to = CGPoint(x: chartOrigin.x + chartWidth, y: y)

                var path = Path()
                path.move(to: from)
                path.addLine(to: to)

                ctx.stroke(
                    path,
                    with: .color(Kalshi.dividerBg),
                    lineWidth: 0.5
                )
            }
        }
    }

    // MARK: - Y-Axis

    private func yAxisLabels(chartHeight: CGFloat) -> some View {
        let minVal = data.min() ?? 0
        let maxVal = data.max() ?? 100
        let insetTop: CGFloat = 6
        let insetBottom: CGFloat = 6
        let drawH = chartHeight - insetTop - insetBottom

        return ZStack(alignment: .topLeading) {
            ForEach(0...ySteps, id: \.self) { i in
                let fraction = CGFloat(i) / CGFloat(ySteps)
                let value = maxVal - (maxVal - minVal) * Double(fraction)
                let y = insetTop + drawH * fraction

                Text("\(Int(value))")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(Kalshi.textMuted)
                    .frame(width: 24, alignment: .trailing)
                    .position(x: 12, y: y)
            }
        }
    }

    // MARK: - Points

    private func normalizedPoints(in size: CGSize, origin: CGPoint) -> [CGPoint] {
        guard data.count >= 2 else { return [] }

        let minVal = data.min() ?? 0
        let maxVal = data.max() ?? 100
        let range = max(maxVal - minVal, 1)

        let insetTop: CGFloat = 6
        let insetBottom: CGFloat = 6
        let drawH = size.height - insetTop - insetBottom

        return data.enumerated().map { index, value in
            let x = origin.x + size.width * CGFloat(index) / CGFloat(data.count - 1)
            let normalized = CGFloat((value - minVal) / range)
            let y = insetTop + drawH * (1 - normalized)
            return CGPoint(x: x, y: y)
        }
    }

    // MARK: - Line Path

    private func linePath(points: [CGPoint]) -> Path {
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

    // MARK: - Fill Path

    private func fillPath(points: [CGPoint], chartOrigin: CGPoint, chartWidth: CGFloat, chartHeight: CGFloat) -> Path {
        var fill = linePath(points: points)
        fill.addLine(to: CGPoint(x: chartOrigin.x + chartWidth, y: chartHeight))
        fill.addLine(to: CGPoint(x: chartOrigin.x, y: chartHeight))
        fill.closeSubpath()
        return fill
    }
}

/// Simple sparkline variant (no axis, no grid) for tight spaces.
struct SparklineChart: View {
    let data: [Double]
    var lineColor: Color = Kalshi.green
    var fillColor: Color = Kalshi.green.opacity(0.08)
    var height: CGFloat = 40
    var lineWidth: CGFloat = 1.5

    var body: some View {
        KalshiLineChart(
            data: data,
            labels: [],
            lineColor: lineColor,
            height: height,
            showYAxis: false
        )
    }
}

#Preview {
    VStack(spacing: 24) {
        // Full Kalshi chart
        VStack(alignment: .leading, spacing: 6) {
            Text("WEEKLY COMPLETION")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Kalshi.textMuted)

            KalshiLineChart(
                data: [40, 55, 70, 60, 80, 75, 90],
                labels: ["M", "T", "W", "T", "F", "S", "S"],
                lineColor: Kalshi.green,
                height: 100
            )

            HStack(spacing: 0) {
                ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { d in
                    Text(d)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Kalshi.textMuted)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.leading, 28)
        }
        .padding(14)
        .background(Kalshi.bg)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Kalshi.cardBorder, lineWidth: 1))

        // Bearish chart
        VStack(alignment: .leading, spacing: 6) {
            Text("DECLINING TREND")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Kalshi.textMuted)

            KalshiLineChart(
                data: [80, 70, 60, 45, 50, 35, 30],
                labels: ["M", "T", "W", "T", "F", "S", "S"],
                lineColor: Kalshi.red,
                height: 100
            )
        }
        .padding(14)
        .background(Kalshi.bg)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Kalshi.cardBorder, lineWidth: 1))
    }
    .padding()
    .background(Kalshi.bg)
}
