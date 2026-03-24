import SwiftUI
import Charts

// MARK: - Tab

private enum FitnessTab: Int {
    case activity = 0
    case trends   = 1
    case vitals   = 2
}

private enum TrendMetric: String, CaseIterable {
    case steps    = "Steps"
    case calories = "Calories"
}

// MARK: - FitnessView

struct FitnessView: View {
    @ObservedObject private var health = HealthKitService.shared
    @State private var hasRequestedAuth = false
    @State private var appeared = false
    @State private var scoreAnimated = false
    @State private var selectedTab: FitnessTab = .activity
    @State private var selectedTrend: TrendMetric = .steps

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                if health.isLoading && health.lastUpdated == nil {
                    loadingView
                } else {
                    fitnessScoreCard
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)

                    activityRingsCard
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 16)

                    tabPicker
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)

                    tabContent
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
        .navigationTitle("Fitness")
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

    // MARK: - Score helpers

    private var scoreColor: Color {
        switch health.fitnessScore {
        case 80...: return .green
        case 60..<80: return .orange
        default: return .red
        }
    }

    private var scoreGrade: String {
        switch health.fitnessScore {
        case 90...: return "A+"
        case 80..<90: return "A"
        case 70..<80: return "B"
        case 60..<70: return "C"
        default: return "D"
        }
    }

    private var scoreLabel: String {
        switch health.fitnessScore {
        case 85...: return "Excellent"
        case 70..<85: return "Good"
        case 55..<70: return "Fair"
        default: return "Needs Work"
        }
    }

    private var scoreSummary: String {
        switch health.fitnessScore {
        case 85...: return "You're smashing your fitness goals. Keep the momentum going!"
        case 70..<85: return "Solid effort today. Hit your exercise goal to push even higher."
        case 55..<70: return "Decent start. A bit more movement will make a real difference."
        default: return "Room to grow. Focus on steps and consistent exercise today."
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 80)
            ProgressView().scaleEffect(1.2)
            Text("Loading fitness data...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Fitness Score Card

    private var fitnessScoreCard: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(scoreColor.opacity(0.12), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: scoreAnimated ? Double(health.fitnessScore) / 100.0 : 0)
                    .stroke(
                        AngularGradient(colors: [scoreColor.opacity(0.55), scoreColor], center: .center),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 1) {
                    Text("\(health.fitnessScore)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(scoreColor)
                    Text(scoreGrade)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(scoreColor.opacity(0.7))
                }
            }
            .frame(width: 88, height: 88)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(scoreLabel)
                        .font(.headline)
                    Spacer()
                    if let updated = health.lastUpdated {
                        HStack(spacing: 3) {
                            Circle().fill(.green).frame(width: 5, height: 5)
                            Text(updated, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                Text(scoreSummary)
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

    // MARK: - Activity Rings Card

    private var activityRingsCard: some View {
        VStack(spacing: 12) {
            HStack {
                Label("Activity Rings", systemImage: "figure.run.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            HStack(spacing: 0) {
                RingColumn(title: "Move",     current: health.exerciseData.calories, goal: 500, unit: "cal", color: .red)
                RingColumn(title: "Exercise", current: health.exerciseData.minutes,  goal: 30,  unit: "min", color: .green)
                RingColumn(title: "Stand",    current: health.standHours,            goal: 12,  unit: "hrs", color: .cyan)
            }
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        Picker("Section", selection: $selectedTab) {
            Text("Activity").tag(FitnessTab.activity)
            Text("Trends").tag(FitnessTab.trends)
            Text("Vitals").tag(FitnessTab.vitals)
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        let transition: AnyTransition = .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal:   .move(edge: .leading).combined(with: .opacity)
        )
        switch selectedTab {
        case .activity: activityTab.transition(transition)
        case .trends:   trendsTab.transition(transition)
        case .vitals:   vitalsTab.transition(transition)
        }
    }

    // MARK: - Activity Tab

    private var activityTab: some View {
        VStack(spacing: 16) {
            stepsSection
            detailsGrid
            if !health.weeklySteps.isEmpty {
                weeklyStepsChart
            }
            if !activityInsights.isEmpty {
                insightsList(activityInsights, color: .orange)
            }
        }
    }

    private var stepsSection: some View {
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(health.exerciseData.steps > 0 ? health.exerciseData.formattedSteps : "--")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
                Text("steps")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Spacer()
                if health.exerciseData.steps > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int(stepsProgress * 100))%")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(stepsProgress >= 1 ? .green : .orange)
                        Text("of 10K goal")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            ProgressView(value: stepsProgress)
                .tint(stepsProgress >= 1 ? .green : .orange)

            HStack(spacing: 16) {
                if health.stepsStreak > 0 {
                    Label("\(health.stepsStreak)-day streak", systemImage: "flame.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                }
                Spacer()
                if let best = health.bestStepsDay {
                    Label("Best: \(best.label) · \(best.value)", systemImage: "trophy.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 20, style: .continuous))
    }

    private var detailsGrid: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                FitnessDetailCell(
                    icon: "point.bottomleft.forward.to.point.topright.scurvepath.fill",
                    label: "Distance",
                    value: String(format: "%.1f mi", health.exerciseData.distance),
                    color: .blue
                )
                Divider().frame(height: 44)
                FitnessDetailCell(icon: "stairs", label: "Floors",
                                  value: "\(health.floorsClimbed)", color: .green)
            }
            Divider().padding(.horizontal, 16)
            HStack(spacing: 0) {
                FitnessDetailCell(icon: "flame.fill", label: "Calories",
                                  value: "\(health.exerciseData.calories) kcal", color: .red)
                Divider().frame(height: 44)
                FitnessDetailCell(icon: "timer", label: "Exercise",
                                  value: "\(health.exerciseData.minutes) min", color: .green)
            }
        }
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .rect(cornerRadius: 20, style: .continuous))
    }

    private var weeklyStepsChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Steps This Week")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Chart(health.weeklySteps) { day in
                BarMark(
                    x: .value("Day", day.label),
                    y: .value("Steps", day.value)
                )
                .foregroundStyle(day.isToday ? .orange : .orange.opacity(0.35))
                .cornerRadius(6)
            }
            .frame(height: 150)

            HStack {
                if let best = health.bestStepsDay {
                    Label("Best: \(best.label) · \(best.value)", systemImage: "trophy.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                // Exclude today's incomplete data from average
                let completed = health.weeklySteps.filter { !$0.isToday }
                let avg = completed.isEmpty ? 0 :
                    Int(completed.map(\.value).reduce(0, +)) / completed.count
                Text("Avg: \(avg)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Trends Tab

    private var trendsTab: some View {
        VStack(spacing: 16) {
            trendChartCard
            trendComparisonCard
        }
    }

    private var trendChartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Metric", selection: $selectedTrend) {
                ForEach(TrendMetric.allCases, id: \.self) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)

            let data   = selectedTrend == .steps ? health.weeklySteps : health.weeklyCalories
            let accent: Color = selectedTrend == .steps ? .orange : .red

            if data.isEmpty {
                Text("No data yet — come back after a workout.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 140)
                    .multilineTextAlignment(.center)
            } else {
                Chart(data) { day in
                    BarMark(
                        x: .value("Day", day.label),
                        y: .value(selectedTrend.rawValue, day.value)
                    )
                    .foregroundStyle(day.isToday ? accent : accent.opacity(0.3))
                    .cornerRadius(6)
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(Color.secondary.opacity(0.3))
                        AxisValueLabel()
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(height: 160)
                .animation(.spring(duration: 0.35), value: selectedTrend)

                // Exclude today's incomplete data from average
                let completedData = data.filter { !$0.isToday }
                let values = completedData.map(\.value)
                let avg    = values.isEmpty ? 0.0 : values.reduce(0, +) / Double(values.count)
                let best   = data.map(\.value).max() ?? 0
                let trend  = weekTrend(data.map(\.value))

                HStack(spacing: 0) {
                    TrendStatCell(label: "Average", value: selectedTrend == .steps ? "\(Int(avg))" : "\(Int(avg)) kcal")
                    Divider().frame(height: 28)
                    TrendStatCell(label: "Best Day", value: selectedTrend == .steps ? "\(Int(best))" : "\(Int(best)) kcal")
                    Divider().frame(height: 28)
                    TrendStatCell(
                        label: "vs Prior",
                        value: "\(trend >= 0 ? "+" : "")\(Int(trend))%",
                        valueColor: trend >= 0 ? .green : .red
                    )
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 20, style: .continuous))
    }

    private var trendComparisonCard: some View {
        VStack(spacing: 0) {
            TrendCompareRow(
                icon: "figure.walk",
                label: "Steps avg",
                value: {
                    let completed = health.weeklySteps.filter { !$0.isToday }
                    guard !completed.isEmpty else { return "--" }
                    return "\(Int(completed.map(\.value).reduce(0,+) / Double(completed.count)))"
                }(),
                goal: "10,000",
                color: .orange
            )
            Divider().padding(.leading, 52)
            TrendCompareRow(
                icon: "flame.fill",
                label: "Calories avg",
                value: {
                    let completed = health.weeklyCalories.filter { !$0.isToday }
                    guard !completed.isEmpty else { return "--" }
                    return "\(Int(completed.map(\.value).reduce(0,+) / Double(completed.count))) kcal"
                }(),
                goal: "500 kcal",
                color: .red
            )
            Divider().padding(.leading, 52)
            TrendCompareRow(
                icon: "timer",
                label: "Exercise avg",
                value: "\(health.exerciseData.minutes) min",
                goal: "30 min",
                color: .green
            )
        }
        .padding(.vertical, 4)
        .glassEffect(.regular, in: .rect(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Vitals Tab

    private var vitalsTab: some View {
        VStack(spacing: 16) {
            recoveryCard

            if health.vo2Max > 0 || health.heartData.resting > 0
                || health.respiratoryRate > 0 || health.mindfulMinutes > 0
                || health.bodyWeight > 0 {
                performanceCard
            }

            if !vitalsInsights.isEmpty {
                insightsList(vitalsInsights, color: .blue)
            }
        }
    }

    private var recoveryCard: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(recoveryColor.opacity(0.12), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: scoreAnimated ? Double(recoveryScore) / 100.0 : 0)
                    .stroke(recoveryColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 1) {
                    Text("\(recoveryScore)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(recoveryColor)
                    Text("%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 80, height: 80)

            VStack(alignment: .leading, spacing: 5) {
                Text("Recovery Readiness")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(recoveryLabel)
                    .font(.headline)
                Text(recoveryRecommendation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)

                if health.hrvData.current > 0 || health.heartData.resting > 0 {
                    HStack(spacing: 6) {
                        if health.hrvData.current > 0 {
                            RecoveryChip(text: "HRV \(health.hrvData.current)ms", color: .blue)
                        }
                        if health.heartData.resting > 0 {
                            RecoveryChip(text: "RHR \(health.heartData.resting)", color: .red)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 20, style: .continuous))
    }

    private var performanceCard: some View {
        VStack(spacing: 0) {
            if health.vo2Max > 0 {
                VitalsRow(
                    icon: "lungs.fill", iconColor: .cyan,
                    label: "VO₂ Max",
                    value: String(format: "%.1f mL/kg·min", health.vo2Max),
                    badge: health.cardioFitnessLevel, badgeColor: fitnessLevelColor
                )
            }
            if health.heartData.resting > 0 {
                if health.vo2Max > 0 { Divider().padding(.leading, 52) }
                VitalsRow(
                    icon: "heart.fill", iconColor: .red,
                    label: "Resting HR",
                    value: "\(health.heartData.resting) bpm",
                    badge: health.heartData.resting <= 60 ? "Athletic" : health.heartData.resting <= 80 ? "Healthy" : "Elevated",
                    badgeColor: health.heartData.resting <= 60 ? .green : health.heartData.resting <= 80 ? .cyan : .orange
                )
            }
            if health.respiratoryRate > 0 {
                Divider().padding(.leading, 52)
                let normal = health.respiratoryRate >= 12 && health.respiratoryRate <= 20
                VitalsRow(
                    icon: "wind", iconColor: .teal,
                    label: "Respiratory Rate",
                    value: String(format: "%.0f breaths/min", health.respiratoryRate),
                    badge: normal ? "Normal" : "Check", badgeColor: normal ? .green : .orange
                )
            }
            if health.mindfulMinutes > 0 {
                Divider().padding(.leading, 52)
                VitalsRow(
                    icon: "brain.head.profile.fill", iconColor: .teal,
                    label: "Mindfulness",
                    value: "\(health.mindfulMinutes) min today",
                    badge: health.mindfulMinutes >= 10 ? "Goal Met" : "In Progress",
                    badgeColor: health.mindfulMinutes >= 10 ? .green : .yellow
                )
            }
            if health.bodyWeight > 0 {
                Divider().padding(.leading, 52)
                VitalsRow(
                    icon: "scalemass.fill", iconColor: .indigo,
                    label: "Body Weight",
                    value: String(format: "%.1f lbs", health.bodyWeight),
                    badge: nil, badgeColor: .clear
                )
            }
        }
        .padding(.vertical, 4)
        .glassEffect(.regular, in: .rect(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Insights List

    private func insightsList(_ items: [String], color: Color) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { i, insight in
                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .fill(color.opacity(0.7))
                        .frame(width: 6, height: 6)
                        .padding(.top, 5)
                    Text(insight)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                if i < items.count - 1 {
                    Divider().padding(.leading, 34)
                }
            }
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Computed helpers

    private var stepsProgress: Double {
        min(Double(health.exerciseData.steps) / 10_000.0, 1.0)
    }

    private var fitnessLevelColor: Color {
        switch health.cardioFitnessLevel {
        case "High":          return .green
        case "Above Average": return .cyan
        case "Average":       return .yellow
        default:              return .orange
        }
    }

    private var recoveryScore: Int {
        var score = 50
        if health.hrvData.current > 0 {
            score += min(25, max(-25, (health.hrvData.current - health.hrvData.baseline) * 2))
        }
        if health.heartData.resting > 0 {
            if health.heartData.resting <= 60      { score += 15 }
            else if health.heartData.resting <= 70 { score += 8  }
            else if health.heartData.resting > 85  { score -= 10 }
        }
        if health.sleepData.hours >= 7 { score += 10 }
        else if health.sleepData.hours > 0 && health.sleepData.hours < 6 { score -= 10 }
        return min(100, max(0, score))
    }

    private var recoveryLabel: String {
        switch recoveryScore {
        case 80...: return "Ready to Train"
        case 60..<80: return "Good"
        case 40..<60: return "Moderate"
        default: return "Rest Recommended"
        }
    }

    private var recoveryColor: Color {
        switch recoveryScore {
        case 75...: return .green
        case 50..<75: return .yellow
        default: return .red
        }
    }

    private var recoveryRecommendation: String {
        switch recoveryScore {
        case 80...: return "Body is primed — ideal day for high intensity or a PR attempt."
        case 60..<80: return "Good for moderate training. Warm up before intense efforts."
        case 40..<60: return "Stick to lighter activity — yoga, walking, or stretching."
        default: return "Prioritize rest. Let your body fully recover before training hard."
        }
    }

    private var activityInsights: [String] { health.activityInsights }
    private var vitalsInsights: [String]   { health.heartInsights }

    private func weekTrend(_ values: [Double]) -> Double {
        guard values.count >= 4 else { return 0 }
        let mid   = values.count / 2
        let first = values.prefix(mid).reduce(0, +) / Double(mid)
        let last  = values.suffix(mid).reduce(0, +) / Double(mid)
        guard first > 0 else { return 0 }
        return (last - first) / first * 100
    }
}

// MARK: - Ring Column

private struct RingColumn: View {
    let title: String
    let current: Int
    let goal: Int
    let unit: String
    let color: Color
    @State private var animatedProgress: Double = 0

    private var progress: Double { min(Double(current) / Double(max(goal, 1)), 1.0) }

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().stroke(color.opacity(0.15), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(current)")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                    Text(unit)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 76, height: 76)
            Text(title).font(.caption.weight(.medium))
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.spring(duration: 1.0, bounce: 0.15).delay(0.2)) { animatedProgress = progress }
        }
        .onChange(of: current) {
            withAnimation(.spring(duration: 0.6, bounce: 0.15)) { animatedProgress = progress }
        }
    }
}

// MARK: - Fitness Detail Cell

private struct FitnessDetailCell: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.subheadline.weight(.semibold))
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Trend Stat Cell

private struct TrendStatCell: View {
    let label: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(valueColor)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Trend Compare Row

private struct TrendCompareRow: View {
    let icon: String
    let label: String
    let value: String
    let goal: String
    let color: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.subheadline).foregroundStyle(.secondary)
                Text(value).font(.headline)
            }
            Spacer()
            Text("Goal: \(goal)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Vitals Row

private struct VitalsRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    let badge: String?
    let badgeColor: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(iconColor)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.subheadline).foregroundStyle(.secondary)
                Text(value).font(.headline)
            }
            Spacer()
            if let badge {
                Text(badge)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(badgeColor.opacity(0.13), in: Capsule())
                    .foregroundStyle(badgeColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Recovery Chip

private struct RecoveryChip: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
            .foregroundStyle(color)
    }
}

#Preview {
    NavigationStack {
        FitnessView()
    }
}
