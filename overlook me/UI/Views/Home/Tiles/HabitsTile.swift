import SwiftUI

struct HabitsTile: View {
    @Environment(\.injected) private var container: DIContainer
    @StateObject private var service = HomeHabitsService()

    private var userId: String {
        container.appState.state.auth.user?.id ?? ""
    }

    var body: some View {
        Group {
            if service.state.isLoading {
                kalshiShimmer("Habits")
            } else if service.state.failed {
                kalshiErrorState("Habits") {
                    _Concurrency.Task { await service.refresh(userId: userId) }
                }
            } else {
                card
            }
        }
        .task {
            guard !userId.isEmpty else { return }
            await service.load(userId: userId)
        }
    }

    // MARK: - Card

    private var card: some View {
        VStack(spacing: 0) {
            // ── Header ──
            headerRow
                .padding(.horizontal, Kalshi.cardPadH)
                .padding(.top, Kalshi.cardPadTop)
                .padding(.bottom, 6)

            // ── Hero number ──
            heroNumber
                .padding(.horizontal, Kalshi.cardPadH)
                .padding(.bottom, 10)

            // ── THE CHART — dominates the card ──
            chartSection
                .padding(.horizontal, Kalshi.cardPadH)
                .padding(.bottom, 12)

            KalshiDivider().padding(.horizontal, Kalshi.cardPadH)

            // ── Metric strip ──
            metricsRow
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

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Header
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var headerRow: some View {
        HStack(spacing: 0) {
            Text("HABITS")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Kalshi.textMuted)

            Spacer()

            // Status badge
            Text(statusLabel)
                .font(.system(size: 10, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(statusFg)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(statusBg, in: Capsule())
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Hero Number (like Kalshi's current price)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var heroNumber: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            // 42% — the big number, like Kalshi shows "Yes 42¢"
            Text("\(service.state.todayPct)%")
                .font(.system(size: 32, weight: .bold))
                .tracking(-1.28)
                .foregroundStyle(Kalshi.textPrimary)

            // Change indicator
            HStack(spacing: 2) {
                Image(systemName: trendArrow)
                    .font(.system(size: 10, weight: .bold))
                Text(trendLabel)
                    .font(.system(size: 12, weight: .bold))
                    .tracking(-0.12)
            }
            .foregroundStyle(trendColor)
            .padding(.leading, 8)

            Spacer()

            // Right: done count
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(service.state.todayCompleted)/\(service.state.todayCount)")
                    .font(.system(size: 14, weight: .bold))
                    .tracking(-0.28)
                    .foregroundStyle(Kalshi.textPrimary)
                Text("DONE")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(Kalshi.textMuted)
            }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - THE CHART
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var chartSection: some View {
        let progress = service.state.weeklyProgress

        return VStack(spacing: 4) {
            if progress.isEmpty {
                // Empty state — flat line placeholder
                Rectangle()
                    .fill(Kalshi.dividerBg)
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .overlay(
                        Text("No data yet")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Kalshi.textMuted)
                    )
            } else {
                // The chart — big, dominant, Kalshi market style
                KalshiLineChart(
                    data: progress.map { Double($0.rate) },
                    labels: progress.map(\.day),
                    lineColor: chartColor,
                    height: 120,
                    showYAxis: true,
                    ySteps: 4
                )

                // X-axis labels
                HStack(spacing: 0) {
                    ForEach(Array(progress.enumerated()), id: \.offset) { i, entry in
                        Text(entry.day)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(
                                i == progress.count - 1
                                    ? Kalshi.textPrimary
                                    : Kalshi.textMuted
                            )
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.leading, 28)
            }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Metrics Row
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var metricsRow: some View {
        HStack(spacing: 0) {
            metricCell("STREAK", "\(service.state.currentStreaks)d", streakColor)
            metricDivider
            metricCell("RATE", "\(service.state.overallRate)%", Kalshi.blue)
            metricDivider
            metricCell("ACTIVE", "\(service.state.activeHabits)", Kalshi.textPrimary)
            metricDivider
            metricCell("BEST", "\(longestStreak)d", Kalshi.amber)
        }
    }

    private func metricCell(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .tracking(-0.28)
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Kalshi.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(Kalshi.cardBorder)
            .frame(width: 1, height: 26)
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Insight Footer
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var insightFooter: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(chartColor)
                .frame(width: 4, height: 4)
            Text(service.state.headline)
                .font(.system(size: 12, weight: .medium))
                .tracking(-0.12)
                .foregroundStyle(Kalshi.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Computed
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var longestStreak: Int {
        service.state.habits.compactMap(\.longestStreak).max() ?? 0
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Colors
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    /// Chart line color — green = good, red = bad (like stock up/down)
    private var chartColor: Color {
        let rates = service.state.weeklyProgress.map(\.rate)
        guard rates.count >= 2 else { return Kalshi.green }
        let trend = rates.last! - rates.first!
        if trend >= 0 { return Kalshi.green }
        return Kalshi.red
    }

    private var streakColor: Color {
        let s = service.state.currentStreaks
        if s >= 14 { return Kalshi.red }
        if s >= 7 { return Kalshi.amber }
        if s >= 1 { return Kalshi.green }
        return Kalshi.textMuted
    }

    // Status badge
    private var statusLabel: String {
        let pct = service.state.todayPct
        if pct == 100 { return "ALL DONE" }
        if pct >= 75 { return "ALMOST" }
        if pct > 0 { return "IN PROGRESS" }
        return "NOT STARTED"
    }

    private var statusFg: Color {
        let pct = service.state.todayPct
        if pct == 100 { return Kalshi.greenDk }
        if pct >= 75 { return Kalshi.blue }
        if pct > 0 { return Kalshi.textSecondary }
        return Kalshi.textMuted
    }

    private var statusBg: Color {
        let pct = service.state.todayPct
        if pct == 100 { return Kalshi.greenBg }
        if pct >= 75 { return Color(red: 0.87, green: 0.93, blue: 1.0) }
        return Kalshi.dividerBg
    }

    // Trend (like stock price change)
    private var trendArrow: String {
        let rates = service.state.weeklyProgress.suffix(3).map(\.rate)
        guard rates.count >= 2 else { return "arrow.right" }
        let d = rates.last! - rates.first!
        if d > 0 { return "arrow.up.right" }
        if d < 0 { return "arrow.down.right" }
        return "arrow.right"
    }

    private var trendLabel: String {
        let rates = service.state.weeklyProgress.suffix(3).map(\.rate)
        guard rates.count >= 2 else { return "—" }
        let d = rates.last! - rates.first!
        if d > 0 { return "+\(d)%" }
        if d < 0 { return "\(d)%" }
        return "0%"
    }

    private var trendColor: Color {
        let rates = service.state.weeklyProgress.suffix(3).map(\.rate)
        guard rates.count >= 2 else { return Kalshi.textMuted }
        let d = rates.last! - rates.first!
        if d > 0 { return Kalshi.green }
        if d < 0 { return Kalshi.red }
        return Kalshi.textMuted
    }
}

// MARK: - Date Formatter

private extension ISO8601DateFormatter {
    static let habitDate: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()
}

// MARK: - Shared Kalshi-styled helpers

private func kalshiStat(_ icon: String, _ color: Color, _ value: String, _ label: String) -> some View {
    HStack(spacing: 5) {
        Image(systemName: icon)
            .font(.system(size: 10))
            .foregroundStyle(color)
            .frame(width: 14)
        Text(value)
            .kalshiBody()
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        Spacer(minLength: 0)
        Text(label)
            .kalshiMetricLabel()
            .lineLimit(1)
    }
}

// MARK: - Shared compact tile loading / error states (Kalshi styled)

func kalshiShimmer(_ title: String) -> some View {
    VStack(spacing: 8) {
        ProgressView().tint(Kalshi.textMuted).scaleEffect(0.8)
        Text(title)
            .kalshiEyebrow()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .frame(minHeight: 280)
    .kalshiCard()
}

func kalshiErrorState(_ title: String, retry: @escaping () -> Void) -> some View {
    VStack(spacing: 8) {
        Image(systemName: "exclamationmark.triangle")
            .font(.system(size: 18))
            .foregroundStyle(Kalshi.textMuted)
        Text(title)
            .kalshiEyebrow()
        Button("Retry", action: retry)
            .buttonStyle(KalshiPillButtonStyle(isPrimary: false))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .frame(minHeight: 280)
    .kalshiCard()
}

#Preview {
    ZStack {
        Kalshi.bg.ignoresSafeArea()
        HabitsTile()
            .padding(.horizontal, 16)
            .environment(\.injected, .previewAuthenticated)
    }
}
