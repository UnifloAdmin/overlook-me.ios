import SwiftUI
import HealthKit
import Charts

struct HealthInsightsView: View {
    @ObservedObject private var health = HealthKitService.shared
    @State private var hasRequestedAuth = false
    @State private var appeared = false
    @State private var scoreAnimated = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                if health.isLoading && health.lastUpdated == nil {
                    loadingView
                } else {
                    wellnessScoreCard
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)

                    atAGlance
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 16)

                    sleepContent
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)

                    heartContent
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 10)

                    hydrationContent
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemBackground))
        .navigationTitle("Health")
        .navigationBarTitleDisplayMode(.large)
        .task {
            guard !hasRequestedAuth else { return }
            hasRequestedAuth = true
            let authorized = await health.requestAuthorization()
            if authorized { await health.fetchAllHealthData() }
            withAnimation(.spring(duration: 0.5, bounce: 0.15)) { appeared = true }
            withAnimation(.spring(duration: 1.2, bounce: 0.1).delay(0.3)) { scoreAnimated = true }
        }
        .refreshable { await health.fetchAllHealthData() }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 80)
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading your health data...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Wellness Score

    private var wellnessScoreCard: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.purple.opacity(0.12), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: scoreAnimated ? Double(health.wellnessScore) / 100.0 : 0)
                    .stroke(
                        AngularGradient(
                            colors: [.purple, .blue, .cyan, .purple],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 1) {
                    Text("\(health.wellnessScore)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("/ 100")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 88, height: 88)

            VStack(alignment: .leading, spacing: 6) {
                Text(wellnessLabel)
                    .font(.headline)
                Text(wellnessSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 20, style: .continuous))
    }

    private var wellnessLabel: String {
        let s = health.wellnessScore
        if s >= 85 { return "Excellent" }
        if s >= 70 { return "Good" }
        if s >= 50 { return "Fair" }
        if s > 0 { return "Needs Attention" }
        return "No Data"
    }

    private var wellnessSummary: String {
        let s = health.wellnessScore
        if s >= 85 { return "You're crushing your health goals. Keep up the great work!" }
        if s >= 70 { return "Solid day so far. A little more activity could push you higher." }
        if s >= 50 { return "Decent progress. Focus on hydration and movement." }
        if s > 0 { return "Room for improvement. Try hitting one more goal today." }
        return "Start tracking to see your wellness score."
    }

    // MARK: - At a Glance

    private var atAGlance: some View {
        VStack(spacing: 0) {
            MetricRow(
                icon: "moon.stars.fill", iconColor: .green, label: "Sleep",
                value: health.sleepData.hours > 0 ? health.sleepData.formattedHours : "--",
                detail: health.sleepData.hours > 0 ? "\(health.sleepData.quality)% quality" : "Last night",
                streak: health.sleepStreak
            )
            Divider().padding(.leading, 52)
            MetricRow(
                icon: "heart.fill", iconColor: .red, label: "Heart Rate",
                value: health.heartData.current > 0 ? "\(health.heartData.current) bpm" : "--",
                detail: health.heartData.resting > 0 ? "Resting \(health.heartData.resting)" : "Current",
                streak: 0
            )
            Divider().padding(.leading, 52)
            MetricRow(
                icon: "drop.fill", iconColor: .blue, label: "Water",
                value: "\(health.waterIntake.current) / \(health.waterIntake.goal)",
                detail: health.waterIntake.current >= health.waterIntake.goal ? "Goal met" : "\(health.waterIntake.goal - health.waterIntake.current) remaining",
                streak: health.waterStreak
            )

            if health.bodyWeight > 0 {
                Divider().padding(.leading, 52)
                MetricRow(
                    icon: "scalemass.fill", iconColor: .pink, label: "Weight",
                    value: String(format: "%.0f lbs", health.bodyWeight),
                    detail: "Latest", streak: 0
                )
            }
            if health.mindfulMinutes > 0 {
                Divider().padding(.leading, 52)
                MetricRow(
                    icon: "brain.head.profile.fill", iconColor: .teal, label: "Mindfulness",
                    value: "\(health.mindfulMinutes) min",
                    detail: "Today", streak: 0
                )
            }
        }
        .padding(.vertical, 4)
        .glassEffect(.regular, in: .rect(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Sleep

    private var sleepContent: some View {
        VStack(spacing: 16) {
            if health.sleepData.hours > 0 {
                VStack(spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(health.sleepData.formattedHours)
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(.green)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(health.sleepData.quality)%")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(health.sleepData.quality >= 70 ? .green : .orange)
                            Text("Quality")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    ProgressView(value: Double(health.sleepData.quality), total: 100)
                        .tint(health.sleepData.quality >= 70 ? .green : .orange)
                }
                .padding(16)
                .glassEffect(.regular, in: .rect(cornerRadius: 20, style: .continuous))

                HStack(spacing: 12) {
                    SleepStageCell(title: "Deep", hours: health.sleepStages.deep, color: .indigo)
                    SleepStageCell(title: "REM", hours: health.sleepStages.rem, color: .purple)
                    SleepStageCell(title: "Light", hours: health.sleepStages.light, color: .cyan)
                    SleepStageCell(title: "Awake", hours: health.sleepStages.awake, color: .orange)
                }
                .padding(14)
                .glassEffect(.regular, in: .rect(cornerRadius: 20, style: .continuous))
            } else {
                EmptyDataRow(icon: "moon.zzz", message: "No sleep data. Wear your Apple Watch to bed.")
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassEffect(.regular, in: .rect(cornerRadius: 20, style: .continuous))
            }

            if !health.weeklySleep.isEmpty {
                VStack(spacing: 10) {
                    Chart(health.weeklySleep) { day in
                        BarMark(x: .value("Day", day.label), y: .value("Hours", day.value))
                            .foregroundStyle(day.isToday ? .green : .green.opacity(0.4))
                            .cornerRadius(6)
                    }
                    .chartYScale(domain: 0...12)
                    .frame(height: 150)

                    if let best = health.bestSleepDay {
                        PersonalBestBadge(label: "Best: \(best.label)", value: String(format: "%.1fh", best.value))
                    }
                }
                .padding(16)
                .glassEffect(.regular, in: .rect(cornerRadius: 20, style: .continuous))
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Bedtime", systemImage: "moon.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(health.sleepSchedule.avgBedtime)
                        .font(.title3.weight(.semibold))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Label("Wake up", systemImage: "sun.max.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(health.sleepSchedule.avgWakeTime)
                        .font(.title3.weight(.semibold))
                }
            }
            .padding(16)
            .glassEffect(.regular, in: .rect(cornerRadius: 20, style: .continuous))

        }
    }

    // MARK: - Heart

    private var heartContent: some View {
        VStack(spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(health.heartData.current > 0 ? "\(health.heartData.current)" : "--")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.red)
                Text("bpm")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(16)
            .glassEffect(.regular, in: .rect(cornerRadius: 20, style: .continuous))

            if health.heartData.resting > 0 || health.heartData.average > 0 || health.heartData.max > 0 {
                HStack(spacing: 0) {
                    HeartMetricCell(title: "Resting", value: health.heartData.resting > 0 ? "\(health.heartData.resting)" : "--", color: .green)
                    Divider().frame(height: 36)
                    HeartMetricCell(title: "Average", value: health.heartData.average > 0 ? "\(health.heartData.average)" : "--", color: .yellow)
                    Divider().frame(height: 36)
                    HeartMetricCell(title: "Peak", value: health.heartData.max > 0 ? "\(health.heartData.max)" : "--", color: .red)
                }
                .padding(.vertical, 14)
                .glassEffect(.regular, in: .rect(cornerRadius: 20, style: .continuous))
            }

            if !health.heartRateHistory.isEmpty {
                Chart(health.heartRateHistory) { point in
                    LineMark(x: .value("Time", point.time), y: .value("BPM", point.value))
                        .foregroundStyle(.red)
                        .interpolationMethod(.catmullRom)
                    AreaMark(x: .value("Time", point.time), y: .value("BPM", point.value))
                        .foregroundStyle(.red.opacity(0.08))
                }
                .chartYScale(domain: 40...180)
                .frame(height: 150)
                .padding(16)
                .glassEffect(.regular, in: .rect(cornerRadius: 20, style: .continuous))
            }

            if health.hrvData.current > 0 {
                VStack(spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(health.hrvData.current) ms")
                                .font(.title2.weight(.bold))
                            Text("HRV")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(health.hrvData.status)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(hrvColor)
                            Text("Baseline: \(health.hrvData.baseline) ms")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text("Higher HRV generally indicates better recovery and lower stress.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(16)
                .glassEffect(.regular, in: .rect(cornerRadius: 20, style: .continuous))
            }

            if health.vo2Max > 0 {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(format: "%.1f", health.vo2Max))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.cyan)
                        Text("VO₂ max · mL/kg·min")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(health.cardioFitnessLevel)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(fitnessLevelColor.opacity(0.15), in: Capsule())
                        .foregroundStyle(fitnessLevelColor)
                }
                .padding(16)
                .glassEffect(.regular, in: .rect(cornerRadius: 20, style: .continuous))
            }

            if health.respiratoryRate > 0 {
                HStack(alignment: .firstTextBaseline) {
                    Text(String(format: "%.0f", health.respiratoryRate))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.mint)
                    Text("breaths/min")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(respiratoryLabel)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(respiratoryColor)
                }
                .padding(16)
                .glassEffect(.regular, in: .rect(cornerRadius: 20, style: .continuous))
            }

        }
    }

    private var fitnessLevelColor: Color {
        switch health.cardioFitnessLevel {
        case "High": return .green
        case "Above Average": return .cyan
        case "Average": return .yellow
        default: return .orange
        }
    }

    private var respiratoryLabel: String {
        let r = health.respiratoryRate
        if r >= 12 && r <= 20 { return "Normal" }
        if r < 12 { return "Low" }
        return "Elevated"
    }

    private var respiratoryColor: Color {
        let r = health.respiratoryRate
        if r >= 12 && r <= 20 { return .green }
        return .orange
    }

    private var hrvColor: Color {
        switch health.hrvData.statusColor {
        case "green": return .green
        case "orange": return .orange
        default: return .secondary
        }
    }

    // MARK: - Hydration

    private var hydrationContent: some View {
        VStack(spacing: 16) {
            VStack(spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(health.waterIntake.current)")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(.blue)
                    Text("/ \(health.waterIntake.goal) glasses")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                HStack(spacing: 6) {
                    ForEach(1...8, id: \.self) { index in
                        Image(systemName: "drop.fill")
                            .font(.title3)
                            .foregroundStyle(index <= health.waterIntake.current ? .blue : Color(.systemGray5))
                            .scaleEffect(index <= health.waterIntake.current ? 1.0 : 0.85)
                            .animation(.spring(duration: 0.3, bounce: 0.4).delay(Double(index) * 0.03), value: health.waterIntake.current)
                            .frame(maxWidth: .infinity)
                    }
                }

                ProgressView(value: Double(health.waterIntake.current), total: Double(health.waterIntake.goal))
                    .tint(.blue)

                Button {
                    _Concurrency.Task { _ = await health.logWater() }
                } label: {
                    Label("Add Glass", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.glass)
                .tint(.blue)
            }
            .padding(16)
            .glassEffect(.regular, in: .rect(cornerRadius: 20, style: .continuous))

            if !health.weeklyWater.isEmpty {
                VStack(spacing: 10) {
                    Chart(health.weeklyWater) { day in
                        BarMark(x: .value("Day", day.label), y: .value("Glasses", day.value))
                            .foregroundStyle(day.value >= 8 ? .blue : .blue.opacity(0.4))
                            .cornerRadius(6)
                    }
                    .chartYScale(domain: 0...12)
                    .frame(height: 140)

                    HStack {
                        // Exclude today's incomplete data from average
                        let completed = health.weeklyWater.filter { !$0.isToday }
                        let avg = completed.isEmpty ? 0 :
                            Int(completed.map(\.value).reduce(0, +)) / completed.count
                        let met = health.weeklyWater.filter { $0.value >= 8 }.count
                        Text("Avg: \(avg) glasses/day")
                        Spacer()
                        Text("\(met)/\(health.weeklyWater.count) days met")
                    }
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                }
                .padding(16)
                .glassEffect(.regular, in: .rect(cornerRadius: 20, style: .continuous))
            }

        }
    }
}

// MARK: - Metric Row

private struct MetricRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    let detail: String
    let streak: Int

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(iconColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.headline)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if streak > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.caption2)
                        Text("\(streak)d")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(.orange)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Sleep Stage Cell

private struct SleepStageCell: View {
    let title: String
    let hours: Double
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 16, height: 16)
            Text(String(format: "%.1fh", hours))
                .font(.subheadline.weight(.semibold))
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Heart Metric Cell

private struct HeartMetricCell: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(value)
                .font(.title3.weight(.bold))
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Personal Best Badge

private struct PersonalBestBadge: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "trophy.fill")
                .font(.caption2)
                .foregroundStyle(.yellow)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
        }
    }
}

// MARK: - Empty Data Row

private struct EmptyDataRow: View {
    let icon: String
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        HealthInsightsView()
    }
}
