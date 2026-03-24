import SwiftUI
import Charts

// MARK: - Kalshi Design Tokens (iOS adaptation)

private enum K {
    // Surfaces
    static let cardBg       = Color.white
    static let cardBorder   = Color(red: 0.94, green: 0.94, blue: 0.96) // #f0f0f0
    static let divider      = Color(red: 0.96, green: 0.96, blue: 0.96) // #f4f4f5
    static let hoverSurface = Color(red: 0.98, green: 0.98, blue: 0.98) // #fafafa

    // Text
    static let textPrimary   = Color(red: 0.035, green: 0.035, blue: 0.043) // #09090b
    static let textSecondary = Color(red: 0.443, green: 0.443, blue: 0.478) // #71717a
    static let textTertiary  = Color(red: 0.631, green: 0.631, blue: 0.667) // #a1a1aa
    static let textPlaceholder = Color(red: 0.831, green: 0.831, blue: 0.847) // #d4d4d8

    // Semantic
    static let done    = Color(red: 0.086, green: 0.639, blue: 0.290) // #16a34a
    static let warning = Color(red: 0.973, green: 0.529, blue: 0.443) // #f87171
    static let fail    = Color(red: 0.863, green: 0.149, blue: 0.149) // #dc2626
    static let today   = Color(red: 0.231, green: 0.510, blue: 0.965) // #3b82f6

    // Radii
    static let cardRadius: CGFloat = 14
    static let pillRadius: CGFloat = 999

    // Spacing
    static let cardPadding: CGFloat = 14
    static let cardGap: CGFloat = 10
}

// MARK: - Card Modifier

private struct KalshiCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(K.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: K.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: K.cardRadius, style: .continuous)
                    .stroke(K.cardBorder, lineWidth: 1)
            )
    }
}

private extension View {
    func kalshiCard() -> some View {
        modifier(KalshiCard())
    }
}

// MARK: - SleepView

struct SleepView: View {
    @ObservedObject private var health = HealthKitService.shared
    @State private var hasRequestedAuth = false
    @State private var appeared = false
    @State private var scoreAnimated = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14) {
                if health.isLoading && health.lastUpdated == nil {
                    loadingView
                } else if health.sleepData.hours <= 0 && health.weeklySleep.isEmpty {
                    emptyState
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 10)
                } else {
                    sleepScoreCard
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 10)

                    lastNightCard
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 10)

                    if hasSleepStages {
                        sleepStagesCard
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 10)
                    }

                    if !health.weeklySleep.isEmpty {
                        weeklySleepChart
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 10)
                    }

                    scheduleCard
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 10)

                    consistencyCard
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 10)

                    if !health.sleepInsights.isEmpty {
                        insightsCard
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 10)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .scrollContentBackground(.hidden)
        .background(Color.white)
        .navigationTitle("Sleep")
        .navigationBarTitleDisplayMode(.large)
        .task {
            guard !hasRequestedAuth else { return }
            hasRequestedAuth = true
            let authorized = await health.requestAuthorization()
            if authorized { await health.fetchAllHealthData() }
            withAnimation(.easeOut(duration: 0.35)) { appeared = true }
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) { scoreAnimated = true }
        }
        .refreshable { await health.fetchAllHealthData() }
    }

    // MARK: - Helpers

    private var hasSleepStages: Bool {
        let s = health.sleepStages
        return s.deep > 0 || s.rem > 0 || s.light > 0 || s.awake > 0
    }

    private var qualityColor: Color {
        let q = health.sleepData.quality
        if q >= 70 { return K.done }
        if q >= 50 { return .orange }
        return K.fail
    }

    private var qualityGrade: String {
        let q = health.sleepData.quality
        if q >= 90 { return "A+" }
        if q >= 80 { return "A" }
        if q >= 70 { return "B" }
        if q >= 60 { return "C" }
        return "D"
    }

    private var qualityLabel: String {
        let q = health.sleepData.quality
        if q >= 80 { return "Excellent" }
        if q >= 60 { return "Good" }
        if q >= 40 { return "Fair" }
        return "Poor"
    }

    private var qualitySummary: String {
        let q = health.sleepData.quality
        if q >= 80 { return "Outstanding rest. You hit ideal deep & REM ratios." }
        if q >= 60 { return "Decent night. A consistent bedtime could push quality higher." }
        if q >= 40 { return "Below average. Try winding down earlier tonight." }
        return "Rough night. Prioritize rest — avoid screens before bed."
    }

    private var durationColor: Color {
        let h = health.sleepData.hours
        if h >= 7 && h <= 9 { return K.done }
        if h >= 6 { return .orange }
        return K.fail
    }

    private var nightsInRange: Int {
        health.weeklySleep.filter { $0.value >= 7 && $0.value <= 9 }.count
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 60)
            ProgressView().scaleEffect(1.1)
            Text("LOADING SLEEP DATA")
                .font(.system(size: 10, weight: .medium))
                .tracking(0.6)
                .foregroundStyle(K.textTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(K.textPlaceholder)

            Text("No Sleep Data")
                .font(.system(size: 14, weight: .semibold))
                .tracking(-0.02 * 14)
                .foregroundStyle(K.textPrimary)

            Text("Wear your Apple Watch to bed, or add sleep data in the Health app.")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(K.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .kalshiCard()
    }

    // MARK: - 1. Sleep Score Card

    private var sleepScoreCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.indigo.opacity(0.10), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: scoreAnimated ? Double(health.sleepData.quality) / 100.0 : 0)
                    .stroke(
                        AngularGradient(
                            colors: [.indigo.opacity(0.5), .purple, .indigo],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(health.sleepData.quality)")
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                        .tracking(-0.04 * 23)
                        .foregroundStyle(K.textPrimary)
                    Text(qualityGrade)
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.06 * 10)
                        .foregroundStyle(K.textTertiary)
                        .textCase(.uppercase)
                }
            }
            .frame(width: 80, height: 80)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(qualityLabel)
                        .font(.system(size: 14, weight: .semibold))
                        .tracking(-0.02 * 14)
                        .foregroundStyle(K.textPrimary)
                    Spacer()
                    if let updated = health.lastUpdated {
                        HStack(spacing: 3) {
                            Circle().fill(K.done).frame(width: 4, height: 4)
                            Text(updated, style: .relative)
                                .font(.system(size: 10, weight: .regular))
                                .foregroundStyle(K.textTertiary)
                        }
                    }
                }
                Text(qualitySummary)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(K.textSecondary)
                    .lineLimit(3)
                    .lineSpacing(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(K.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .kalshiCard()
    }

    // MARK: - 2. Last Night Summary

    private var lastNightCard: some View {
        VStack(spacing: K.cardGap) {
            HStack {
                Text("LAST NIGHT")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.06 * 10)
                    .foregroundStyle(K.textTertiary)
                Spacer()
            }

            HStack(alignment: .firstTextBaseline) {
                Text(health.sleepData.formattedHours)
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .tracking(-0.04 * 23)
                    .foregroundStyle(K.textPrimary)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(health.sleepData.quality)%")
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                        .tracking(-0.04 * 23)
                        .foregroundStyle(qualityColor)
                    Text("QUALITY")
                        .font(.system(size: 10, weight: .medium))
                        .tracking(0.06 * 10)
                        .foregroundStyle(K.textTertiary)
                }
            }

            // Thin progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(K.divider).frame(height: 5)
                    Capsule().fill(qualityColor)
                        .frame(width: geo.size.width * min(Double(health.sleepData.quality) / 100.0, 1.0), height: 5)
                }
            }
            .frame(height: 5)

            HStack(spacing: 12) {
                if health.sleepStreak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.orange)
                        Text("\(health.sleepStreak)-DAY STREAK")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(0.06 * 10)
                            .foregroundStyle(K.textSecondary)
                    }
                }
                Spacer()
                if let best = health.bestSleepDay {
                    HStack(spacing: 4) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.yellow)
                        Text("Best: \(best.label) · \(String(format: "%.1fh", best.value))")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(K.textTertiary)
                    }
                }
            }
        }
        .padding(K.cardPadding)
        .kalshiCard()
    }

    // MARK: - 3. Sleep Stages

    private var sleepStagesCard: some View {
        VStack(spacing: K.cardGap) {
            HStack {
                Text("SLEEP STAGES")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.06 * 10)
                    .foregroundStyle(K.textTertiary)
                Spacer()
            }

            HStack(spacing: 8) {
                SleepStagePill(title: "DEEP", hours: health.sleepStages.deep, color: .indigo)
                SleepStagePill(title: "REM", hours: health.sleepStages.rem, color: .purple)
                SleepStagePill(title: "LIGHT", hours: health.sleepStages.light, color: .cyan)
                SleepStagePill(title: "AWAKE", hours: health.sleepStages.awake, color: .orange)
            }

            sleepStagesBar
        }
        .padding(K.cardPadding)
        .kalshiCard()
    }

    private var sleepStagesBar: some View {
        let stages = health.sleepStages
        let total = max(stages.deep + stages.rem + stages.light + stages.awake, 0.01)

        return GeometryReader { geo in
            HStack(spacing: 2) {
                if stages.deep > 0 {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.indigo)
                        .frame(width: geo.size.width * stages.deep / total)
                }
                if stages.rem > 0 {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.purple)
                        .frame(width: geo.size.width * stages.rem / total)
                }
                if stages.light > 0 {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.cyan)
                        .frame(width: geo.size.width * stages.light / total)
                }
                if stages.awake > 0 {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.orange)
                        .frame(width: geo.size.width * stages.awake / total)
                }
            }
        }
        .frame(height: 7)
        .clipShape(RoundedRectangle(cornerRadius: K.pillRadius))
    }

    // MARK: - 4. Weekly Sleep Chart

    private var weeklySleepChart: some View {
        VStack(alignment: .leading, spacing: K.cardGap) {
            Text("WEEKLY SLEEP")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.06 * 10)
                .foregroundStyle(K.textTertiary)

            Chart(health.weeklySleep) { day in
                BarMark(
                    x: .value("Day", day.label),
                    y: .value("Hours", day.value)
                )
                .foregroundStyle(day.isToday ? Color.indigo : Color.indigo.opacity(0.25))
                .cornerRadius(4)

                RuleMark(y: .value("Goal", 8))
                    .foregroundStyle(K.done.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
            .chartYScale(domain: 0...12)
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                        .foregroundStyle(K.cardBorder)
                    AxisValueLabel()
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(K.textTertiary)
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(K.textTertiary)
                }
            }
            .frame(height: 140)

            // Stats row
            HStack(spacing: 0) {
                // Exclude today's incomplete data from average
                let completedDays = health.weeklySleep.filter { !$0.isToday }
                let values = completedDays.map(\.value)
                let avg = values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
                let best = values.max() ?? 0

                SleepStatCell(label: "AVERAGE", value: String(format: "%.1fh", avg))
                dividerLine
                SleepStatCell(label: "BEST NIGHT", value: String(format: "%.1fh", best))
                dividerLine
                SleepStatCell(label: "GOAL MET", value: "\(nightsInRange)/7",
                              valueColor: nightsInRange >= 5 ? K.done : .orange)
            }
        }
        .padding(K.cardPadding)
        .kalshiCard()
    }

    private var dividerLine: some View {
        Rectangle()
            .fill(Color(red: 0.894, green: 0.894, blue: 0.906)) // #e4e4e7
            .frame(width: 1, height: 26)
    }

    // MARK: - 5. Bedtime & Wake Schedule

    private var scheduleCard: some View {
        VStack(spacing: K.cardGap) {
            HStack {
                Text("SCHEDULE")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.06 * 10)
                    .foregroundStyle(K.textTertiary)
                Spacer()
            }

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Image(systemName: "moon.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.indigo)
                        Text("BEDTIME")
                            .font(.system(size: 10, weight: .medium))
                            .tracking(0.06 * 10)
                            .foregroundStyle(K.textTertiary)
                    }
                    Text(health.sleepSchedule.avgBedtime)
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                        .tracking(-0.04 * 23)
                        .foregroundStyle(K.textPrimary)
                }
                Spacer()
                dividerLine
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    HStack(spacing: 4) {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.orange)
                        Text("WAKE UP")
                            .font(.system(size: 10, weight: .medium))
                            .tracking(0.06 * 10)
                            .foregroundStyle(K.textTertiary)
                    }
                    Text(health.sleepSchedule.avgWakeTime)
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                        .tracking(-0.04 * 23)
                        .foregroundStyle(K.textPrimary)
                }
            }
        }
        .padding(K.cardPadding)
        .kalshiCard()
    }

    // MARK: - 6. Sleep Consistency

    private var consistencyCard: some View {
        VStack(spacing: K.cardGap) {
            HStack {
                Text("CONSISTENCY")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.06 * 10)
                    .foregroundStyle(K.textTertiary)
                Spacer()
                Text("\(nightsInRange)/7 IN RANGE")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.06 * 10)
                    .foregroundStyle(nightsInRange >= 5 ? K.done : .orange)
            }

            // 7-day segment strip
            HStack(spacing: 3) {
                ForEach(Array(health.weeklySleep.enumerated()), id: \.element.id) { _, day in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(daySegmentColor(for: day))
                            .frame(height: 20)

                        Text(String(day.label.prefix(1)))
                            .font(.system(size: 9, weight: .medium))
                            .tracking(0.04 * 9)
                            .foregroundStyle(day.isToday ? K.today : K.textTertiary)
                            .textCase(.uppercase)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            // Legend
            HStack(spacing: 10) {
                legendPill(color: K.done, label: "7–9h")
                legendPill(color: Color(red: 0.988, green: 0.749, blue: 0.149), label: "Off range") // #fbbf24
                legendPill(color: K.divider.opacity(0.5), label: "No data")
                Spacer()
            }
        }
        .padding(K.cardPadding)
        .kalshiCard()
    }

    private func daySegmentColor(for day: WeeklyDataPoint) -> Color {
        if day.value <= 0 { return K.divider.opacity(0.5) }
        if day.value >= 7 && day.value <= 9 { return K.done }
        return Color(red: 0.988, green: 0.749, blue: 0.149) // #fbbf24 — skipped/off-range
    }

    private func legendPill(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(K.textTertiary)
        }
    }

    // MARK: - 7. Sleep Insights

    private var insightsCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("INSIGHTS")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.06 * 10)
                    .foregroundStyle(K.textTertiary)
                Spacer()
            }
            .padding(.horizontal, K.cardPadding)
            .padding(.top, K.cardPadding)
            .padding(.bottom, 6)

            ForEach(Array(health.sleepInsights.enumerated()), id: \.offset) { i, insight in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(Color.indigo.opacity(0.6))
                        .frame(width: 5, height: 5)
                        .padding(.top, 5)
                    Text(insight)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(K.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
                .padding(.horizontal, K.cardPadding)
                .padding(.vertical, 8)
                if i < health.sleepInsights.count - 1 {
                    Rectangle()
                        .fill(K.cardBorder)
                        .frame(height: 1)
                        .padding(.leading, K.cardPadding + 15)
                }
            }

            Spacer().frame(height: 6)
        }
        .kalshiCard()
    }
}

// MARK: - Sleep Stage Pill

private struct SleepStagePill: View {
    let title: String
    let hours: Double
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(String(format: "%.1fh", hours))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .tracking(-0.02 * 14)
                .foregroundStyle(K.textPrimary)
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .tracking(0.04 * 9)
                .foregroundStyle(K.textTertiary)

            RoundedRectangle(cornerRadius: K.pillRadius)
                .fill(color)
                .frame(height: 3)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Sleep Stat Cell

private struct SleepStatCell: View {
    let label: String
    let value: String
    var valueColor: Color = K.textPrimary

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .tracking(-0.02 * 14)
                .foregroundStyle(valueColor)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .tracking(0.04 * 9)
                .foregroundStyle(K.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack {
        SleepView()
    }
}
