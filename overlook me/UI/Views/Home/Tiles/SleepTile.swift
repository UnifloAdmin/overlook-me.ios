import SwiftUI

struct SleepTile: View {
    @ObservedObject private var health = HealthKitService.shared
    @State private var hasStarted = false

    var body: some View {
        Group {
            if health.isLoading && !hasStarted {
                loadingCard
            } else if health.sleepData.hours == 0 && health.weeklySleep.isEmpty {
                emptyCard
            } else {
                sleepCard
            }
        }
        .task {
            guard !hasStarted else { return }
            hasStarted = true
            let authorized = await health.requestAuthorization()
            if authorized { await health.fetchAllHealthData() }
        }
    }

    // MARK: - Loading

    private var loadingCard: some View {
        HStack(spacing: 8) {
            ProgressView().tint(Kalshi.textMuted).scaleEffect(0.85)
            Text("SLEEP")
                .kalshiEyebrow()
        }
        .frame(maxWidth: .infinity)
        .frame(height: 160)
        .kalshiCard()
    }

    // MARK: - Empty

    private var emptyCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "moon.zzz")
                .font(.system(size: 16))
                .foregroundStyle(Kalshi.textMuted)
            Text("Wear your Apple Watch to bed to track sleep")
                .kalshiSecondary()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Kalshi.cardPadH)
        .kalshiCard()
    }

    // MARK: - Main Card

    private var sleepCard: some View {
        VStack(spacing: 0) {
            headerSection
            KalshiDivider().padding(.horizontal, Kalshi.cardPadH)
            weeklyAverageSection
            KalshiDivider().padding(.horizontal, Kalshi.cardPadH)
            comparisonSection
            KalshiDivider().padding(.horizontal, Kalshi.cardPadH)
            insightBar
        }
        .kalshiCard()
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 4) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 10))
                .foregroundStyle(Kalshi.textMuted)
            Text("SLEEP")
                .kalshiEyebrow()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Kalshi.cardPadH)
        .padding(.vertical, 10)
    }

    // MARK: - Weekly Average (hero number)

    private var weeklyAverageSection: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(formattedHours(weeklyAvg))
                    .kalshiMetric()
                Text("WEEKLY AVERAGE")
                    .kalshiMetricLabel()
            }

            Spacer()

            // Quality as a metric
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(avgQuality)%")
                    .font(.system(size: 23, weight: .bold))
                    .tracking(-0.92)
                    .foregroundStyle(avgQuality >= 70 ? Kalshi.green : Kalshi.orange)
                Text("QUALITY")
                    .kalshiMetricLabel()
            }
        }
        .padding(.horizontal, Kalshi.cardPadH)
        .padding(.vertical, Kalshi.cardPadTop)
    }

    // MARK: - Today vs Yesterday Comparison

    private var comparisonSection: some View {
        HStack(spacing: 14) {
            comparisonBar(
                label: "YESTERDAY",
                hours: yesterdayHours,
                color: Kalshi.green.opacity(0.4)
            )
            comparisonBar(
                label: "LAST NIGHT",
                hours: health.sleepData.hours,
                color: Kalshi.green
            )
        }
        .padding(.horizontal, Kalshi.cardPadH)
        .padding(.vertical, Kalshi.cardPadTop)
    }

    private func comparisonBar(label: String, hours: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .kalshiMetricLabel()

            HStack(spacing: 6) {
                // Bar — flat fill, no gradient
                let maxHours = max(health.sleepData.hours, yesterdayHours, 8)
                let fraction = maxHours > 0 ? CGFloat(hours / maxHours) : 0

                RoundedRectangle(cornerRadius: Kalshi.segRadius, style: .continuous)
                    .fill(color)
                    .frame(height: 20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .scaleEffect(x: max(0.02, fraction), y: 1, anchor: .leading)
                    .animation(Kalshi.normal, value: fraction)

                Text(hours > 0 ? formattedHours(hours) : "--")
                    .kalshiBody()
                    .frame(width: 44, alignment: .trailing)
            }

            // Delta
            if hours > 0 && label == "LAST NIGHT" && yesterdayHours > 0 {
                let diff = hours - yesterdayHours
                let diffMin = Int(abs(diff) * 60)
                if diffMin >= 5 {
                    HStack(spacing: 3) {
                        Image(systemName: diff > 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 9, weight: .bold))
                        Text("\(diffMin) min \(diff > 0 ? "more" : "less")")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(0.1)
                    }
                    .foregroundStyle(diff > 0 ? Kalshi.green : Kalshi.orange)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Insight

    private var insightBar: some View {
        Text(sleepInsight)
            .kalshiSecondary()
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Kalshi.cardPadH)
            .padding(.vertical, 10)
    }

    // MARK: - Computed

    private var weeklyAvg: Double {
        let data = health.weeklySleep.map(\.value)
        guard !data.isEmpty else { return health.sleepData.hours }
        let tracked = data.filter { $0 > 0 }
        guard !tracked.isEmpty else { return 0 }
        return tracked.reduce(0, +) / Double(tracked.count)
    }

    private var avgQuality: Int {
        health.sleepData.quality
    }

    private var yesterdayHours: Double {
        guard health.weeklySleep.count >= 2 else { return 0 }
        return health.weeklySleep[health.weeklySleep.count - 2].value
    }

    private var sleepInsight: String {
        let today = health.sleepData.hours
        let avg = weeklyAvg
        let diff = today - avg

        if today == 0 { return "No sleep data recorded yet" }
        if today >= 7 && today <= 9 && health.sleepData.quality >= 75 {
            return "Great night — right in the sweet spot"
        }
        if abs(diff) > 0.5 {
            let direction = diff > 0 ? "more" : "less"
            return "You slept \(Int(abs(diff) * 60)) min \(direction) than your weekly average"
        }
        if today < 6 { return "Short night — a nap might help today" }
        if health.sleepData.quality < 60 { return "Sleep quality was low — try a consistent bedtime" }
        return "Consistent sleep — keep it up"
    }

    private func formattedHours(_ h: Double) -> String {
        let hrs = Int(h)
        let mins = Int((h - Double(hrs)) * 60)
        return mins > 0 ? "\(hrs)h \(mins)m" : "\(hrs)h"
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Kalshi.bg.ignoresSafeArea()
        SleepTile()
            .padding(.horizontal, 16)
    }
}
