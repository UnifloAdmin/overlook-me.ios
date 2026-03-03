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
            ProgressView().tint(.secondary).scaleEffect(0.85)
            Text("Sleep")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 160)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Empty

    private var emptyCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "moon.zzz")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Wear your Apple Watch to bed to track sleep")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Main Card

    private var sleepCard: some View {
        VStack(spacing: 0) {
            headerSection
            Divider().padding(.horizontal, 16)
            weeklyAverageSection
            Divider().padding(.horizontal, 16)
            comparisonSection
            Divider().padding(.horizontal, 16)
            insightBar
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Header

    private var headerSection: some View {
        Label {
            Text("Sleep")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
        } icon: {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 11))
                .foregroundStyle(.green)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Weekly Average (hero number)

    private var weeklyAverageSection: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(formattedHours(weeklyAvg))
                    .font(.system(size: 34, weight: .thin, design: .rounded))
                    .foregroundStyle(.primary)
                Text("weekly average")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(avgQuality)%")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(avgQuality >= 70 ? .green : .orange)
                Text("quality")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Today vs Yesterday Comparison

    private var comparisonSection: some View {
        HStack(spacing: 16) {
            comparisonBar(
                label: "Yesterday",
                hours: yesterdayHours,
                color: .green.opacity(0.5)
            )
            comparisonBar(
                label: "Last night",
                hours: health.sleepData.hours,
                color: .green
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func comparisonBar(label: String, hours: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                // Bar
                let maxHours = max(health.sleepData.hours, yesterdayHours, 8)
                let fraction = maxHours > 0 ? CGFloat(hours / maxHours) : 0

                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(color)
                    .frame(height: 24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .scaleEffect(x: max(0.02, fraction), y: 1, anchor: .leading)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: fraction)

                Text(hours > 0 ? formattedHours(hours) : "--")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .frame(width: 48, alignment: .trailing)
            }

            // Delta if both have data
            if hours > 0 && label == "Last night" && yesterdayHours > 0 {
                let diff = hours - yesterdayHours
                let diffMin = Int(abs(diff) * 60)
                if diffMin >= 5 {
                    HStack(spacing: 3) {
                        Image(systemName: diff > 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 9, weight: .bold))
                        Text("\(diffMin) min \(diff > 0 ? "more" : "less")")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(diff > 0 ? .green : .orange)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Insight

    private var insightBar: some View {
        Text(sleepInsight)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
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
        Color(.systemGroupedBackground).ignoresSafeArea()
        SleepTile()
            .padding(.horizontal, 20)
    }
}
