import SwiftUI
import Charts

// MARK: - Design Tokens

private enum WaterStyle {
    /// Cyan accent — mirrors web `$c-cyan`
    static let cyan     = Color(red: 0.024, green: 0.714, blue: 0.831)   // #06b6d4
    static let cyanDark = Color(red: 0.035, green: 0.569, blue: 0.698)   // #0891b2
    static let cyanBg   = Color(red: 0.024, green: 0.714, blue: 0.831).opacity(0.08)
    static let cyanGlow = Color(red: 0.024, green: 0.714, blue: 0.831).opacity(0.18)

    static let amber = Color(red: 0.961, green: 0.620, blue: 0.043)      // #f59e0b
    static let green = Color(red: 0.086, green: 0.639, blue: 0.290)      // #16a34a
}

// MARK: - Local Data Models (mock — replace with real API models)

struct WaterLog: Identifiable {
    let id = UUID()
    var amountMl: Int
    var source: String
    var loggedAt: Date
}

struct WaterMilestone: Identifiable {
    let id = UUID()
    var title: String
    var description: String
    var requiredL: Double
    var achievedL: Double
    var isAchieved: Bool
    var progress: Double { min(1, achievedL / max(requiredL, 0.001)) }
}

// MARK: - WaterTrackerView

struct WaterTrackerView: View {

    // MARK: - State
    @State private var activeTab: Tab = .dashboard
    @State private var showLogSheet = false
    @State private var logSuccess  = false

    // Dashboard data (mock — swap with @StateObject / EnvironmentObject)
    @State private var todayMl:    Int    = 1350
    @State private var goalMl:     Int    = 2500
    @State private var streak:     Int    = 7
    @State private var bestStreak: Int    = 14
    @State private var allLogs:    [WaterLog] = WaterTrackerView.mockLogs()

    // Log form
    @State private var customAmount: Int    = 250
    @State private var selectedSource: String = "water"

    // Quick-add amount (set from pill, presented in sheet)
    @State private var quickAmount: Int? = nil

    enum Tab: String, CaseIterable, Identifiable {
        case dashboard  = "Dashboard"
        case log        = "Log"
        case trends     = "Trends"
        case milestones = "Milestones"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .dashboard:  return "drop.fill"
            case .log:        return "plus.circle.fill"
            case .trends:     return "chart.bar.fill"
            case .milestones: return "star.fill"
            }
        }
    }

    // MARK: - Computed

    var todayPercent: Double { min(1, Double(todayMl) / Double(max(goalMl, 1))) }
    var remainingMl:  Int    { max(0, goalMl - todayMl) }
    var todayLogs:    [WaterLog] {
        allLogs.filter { Calendar.current.isDateInToday($0.loggedAt) }
    }

    var last7Days: [(label: String, ml: Int)] {
        let days = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
        return (0..<7).reversed().map { offset in
            let date = Calendar.current.date(byAdding: .day, value: -offset, to: Date())!
            let ml   = allLogs.filter { Calendar.current.isDate($0.loggedAt, inSameDayAs: date) }
                              .reduce(0) { $0 + $1.amountMl }
            return (days[Calendar.current.component(.weekday, from: date) - 1], ml)
        }.reversed()
    }

    var weeklyAvg: Int { last7Days.isEmpty ? 0 : last7Days.map(\.ml).reduce(0,+) / 7 }
    var totalLifetimeL: Double { Double(allLogs.reduce(0){$0+$1.amountMl}) / 1000 }

    var milestones: [WaterMilestone] {
        let lifetime = totalLifetimeL
        let targets: [(String, String, Double)] = [
            ("First Drop",    "Log your first 1 L",           1),
            ("Hydration Pro", "Reach 10 L total",             10),
            ("Half Century",  "50 L lifetime logged",         50),
            ("Centurion",     "100 L — you're unstoppable!",  100),
            ("Everyday Hero", "500 L — daily warrior",        500),
        ]
        return targets.map { WaterMilestone(
            title: $0.0, description: $0.1,
            requiredL: $0.2, achievedL: min($0.2, lifetime),
            isAchieved: lifetime >= $0.2
        )}
    }

    var sourceBreakdown: [(source: String, pct: Int)] {
        let total = allLogs.reduce(0) { $0 + $1.amountMl }
        guard total > 0 else { return [] }
        let grouped = Dictionary(grouping: allLogs, by: \.source)
            .mapValues { $0.reduce(0) { $0 + $1.amountMl } }
        return grouped.map { (source: $0.key, pct: Int(Double($0.value)/Double(total)*100)) }
            .sorted { $0.pct > $1.pct }
    }

    // MARK: - Body

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 14) {
                    tabBar
                        .padding(.horizontal, 16)

                    Group {
                        switch activeTab {
                        case .dashboard:  dashboardTab
                        case .log:        logTab
                        case .trends:     trendsTab
                        case .milestones: milestonesTab
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 20)
                .padding(.bottom, 48)
                .background(Color.kalBackground)
            }
        }
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .background(Color.kalBackground)
        .navigationTitle("Hydration")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showLogSheet = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showLogSheet) { logSheet }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.76)) {
                        activeTab = tab
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: tab.icon).font(.system(size: 10, weight: .semibold))
                        Text(tab.rawValue).font(.system(size: 11, weight: .semibold)).tracking(-0.1)
                    }
                    .foregroundStyle(activeTab == tab ? Color.kalBackground : Color.kalMuted)
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(
                        Capsule().fill(activeTab == tab ? WaterStyle.cyan : Color.clear)
                    )
                }
                .buttonStyle(.plain)
                if tab != Tab.allCases.last { Spacer(minLength: 0) }
            }
        }
        .padding(4)
        .background(Color.kalInput, in: Capsule())
    }

    // MARK: ═══════════════════════════════════════════════════════
    // DASHBOARD TAB
    // ════════════════════════════════════════════════════════════

    private var dashboardTab: some View {
        VStack(spacing: 14) {

            // ── Gauge Card ──
            gaugeCard

            // ── KPI Row ──
            kpiRow

            // ── Quick Add Pills ──
            quickAddSection

            // ── Recent Logs ──
            recentLogsCard
        }
    }

    // Circular gauge with animated progress ring
    private var gaugeCard: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.kalDivider, lineWidth: 10)
                    .frame(width: 110, height: 110)

                Circle()
                    .trim(from: 0, to: todayPercent)
                    .stroke(
                        LinearGradient(colors: [WaterStyle.cyan, WaterStyle.cyanDark],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 110, height: 110)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(duration: 0.8, bounce: 0.1), value: todayPercent)

                VStack(spacing: 1) {
                    Text("\(Int(todayPercent * 100))%")
                        .font(.system(size: 22, weight: .bold)).tracking(-0.8)
                        .foregroundStyle(Color.kalPrimary)
                    Text("of goal")
                        .font(.system(size: 9, weight: .medium)).tracking(0.3)
                        .foregroundStyle(Color.kalTertiary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(formatMl(todayMl))
                        .font(.system(size: 28, weight: .heavy)).tracking(-1)
                        .foregroundStyle(Color.kalPrimary)
                    Text("of \(formatMl(goalMl))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.kalTertiary)
                }

                HStack(spacing: 6) {
                    if remainingMl > 0 {
                        Image(systemName: "drop").font(.system(size: 10))
                        Text("\(formatMl(remainingMl)) remaining")
                            .font(.system(size: 11, weight: .medium))
                    } else {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 11))
                        Text("Goal reached!")
                            .font(.system(size: 11, weight: .semibold))
                    }
                }
                .foregroundStyle(remainingMl == 0 ? WaterStyle.cyan : Color.kalMuted)

                // Mini progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.kalDivider).frame(height: 5)
                        Capsule()
                            .fill(LinearGradient(colors: [WaterStyle.cyan, WaterStyle.cyanDark],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * todayPercent, height: 5)
                            .animation(.spring(duration: 0.6, bounce: 0.1), value: todayPercent)
                    }
                }
                .frame(height: 5)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .kalshiCard()
        .overlay(alignment: .topTrailing) {
            // Subtle cyan glow
            Circle()
                .fill(WaterStyle.cyanGlow)
                .frame(width: 80, height: 80)
                .blur(radius: 24)
                .offset(x: 10, y: -10)
                .allowsHitTesting(false)
        }
        .clipped()
    }

    // KPI row — streak · weekly avg · goals hit
    private var kpiRow: some View {
        HStack(spacing: 10) {
            kpiCard(
                icon: "flame.fill", iconColor: WaterStyle.amber,
                value: "\(streak)", label: "STREAK",
                sub: "Best \(bestStreak)d"
            )
            kpiCard(
                icon: "chart.line.uptrend.xyaxis", iconColor: WaterStyle.cyan,
                value: formatMl(weeklyAvg), label: "DAILY AVG",
                sub: "Last 7 days"
            )
            kpiCard(
                icon: "checkmark.circle.fill", iconColor: WaterStyle.green,
                value: "\(milestones.filter(\.isAchieved).count)", label: "MILESTONES",
                sub: "All time"
            )
        }
    }

    private func kpiCard(icon: String, iconColor: Color,
                         value: String, label: String, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold)).foregroundStyle(iconColor)
                Text(label)
                    .font(.system(size: 9, weight: .bold)).tracking(0.6)
                    .foregroundStyle(Color.kalTertiary)
            }
            Text(value)
                .font(.system(size: 20, weight: .bold)).tracking(-0.8)
                .foregroundStyle(Color.kalPrimary)
                .contentTransition(.numericText())
            Text(sub)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.kalTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .kalshiCard()
    }

    // Quick Add Pills
    private var quickAddSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            eyebrow("QUICK ADD")
            HStack(spacing: 8) {
                ForEach(quickOptions, id: \.0) { (label, ml, icon) in
                    quickPill(label: label, ml: ml, icon: icon)
                }
            }
        }
    }

    private var quickOptions: [(String, Int, String)] {
        [("250ml", 250, "drop.fill"),
         ("500ml", 500, "drop.fill"),
         ("750ml", 750, "drop.fill"),
         ("1 L",   1000, "waterbottle.fill")]
    }

    private func quickPill(label: String, ml: Int, icon: String) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            addLog(ml: ml, source: "water")
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(WaterStyle.cyan)
                Text(label)
                    .font(.system(size: 11, weight: .bold)).tracking(-0.2)
                    .foregroundStyle(Color.kalPrimary)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .background(WaterStyle.cyanBg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(WaterStyle.cyan.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // Recent Logs timeline
    private var recentLogsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                eyebrow("RECENT INTAKE")
                Spacer()
                Text("\(todayLogs.count) today")
                    .font(.system(size: 10, weight: .medium)).foregroundStyle(Color.kalTertiary)
            }

            if todayLogs.isEmpty {
                emptyState(icon: "drop", message: "No intake logged yet — start hydrating!")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(todayLogs.prefix(5).enumerated()), id: \.element.id) { i, log in
                        HStack(spacing: 12) {
                            // Timeline dot
                            VStack(spacing: 0) {
                                Circle()
                                    .fill(i == 0 ? WaterStyle.cyan : Color.kalDivider)
                                    .frame(width: 8, height: 8)
                                    .shadow(color: i == 0 ? WaterStyle.cyanGlow : .clear, radius: 4)
                                if i < todayLogs.prefix(5).count - 1 {
                                    Rectangle().fill(Color.kalDivider).frame(width: 1).padding(.vertical, 2)
                                }
                            }
                            .frame(width: 8)

                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(formatMl(log.amountMl))
                                        .font(.system(size: 14, weight: .semibold)).tracking(-0.3)
                                        .foregroundStyle(Color.kalPrimary)
                                    Text(sourceLabel(log.source))
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Color.kalMuted)
                                }
                                Spacer()
                                Text(timeAgo(log.loggedAt))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(Color.kalTertiary)
                            }
                            .padding(.vertical, 10)
                        }
                        if i < todayLogs.prefix(5).count - 1 {
                            Divider().padding(.leading, 20)
                        }
                    }
                }
            }
        }
        .padding(16)
        .kalshiCard()
    }

    // MARK: ═══════════════════════════════════════════════════════
    // LOG TAB
    // ════════════════════════════════════════════════════════════

    private var logTab: some View {
        VStack(spacing: 14) {

            // Today's progress ring
            todayProgressCard

            // Custom amount stepper
            customAmountCard

            // Source selector
            sourceCard

            // Log button
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                addLog(ml: customAmount, source: selectedSource)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "drop.fill").font(.system(size: 13))
                    Text("Log \(formatMl(customAmount))")
                        .font(.system(size: 14, weight: .semibold)).tracking(-0.3)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(WaterStyle.cyan, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            // Success toast
            if logSuccess {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(WaterStyle.cyan)
                    Text("Logged successfully!")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(WaterStyle.cyanDark)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(WaterStyle.cyanBg, in: Capsule())
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var todayProgressCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().stroke(Color.kalDivider, lineWidth: 8).frame(width: 70, height: 70)
                Circle()
                    .trim(from: 0, to: todayPercent)
                    .stroke(WaterStyle.cyan, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 70, height: 70).rotationEffect(.degrees(-90))
                    .animation(.spring(duration: 0.6, bounce: 0.1), value: todayPercent)
                Text("\(Int(todayPercent*100))%")
                    .font(.system(size: 14, weight: .bold)).tracking(-0.5)
                    .foregroundStyle(Color.kalPrimary)
            }
            VStack(alignment: .leading, spacing: 4) {
                eyebrow("TODAY'S PROGRESS")
                Text("\(formatMl(todayMl)) / \(formatMl(goalMl))")
                    .font(.system(size: 17, weight: .bold)).tracking(-0.5)
                    .foregroundStyle(Color.kalPrimary)
                Text(remainingMl > 0 ? "\(formatMl(remainingMl)) to go" : "Goal reached 🎉")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(Color.kalMuted)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .kalshiCard()
    }

    private var customAmountCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            eyebrow("CUSTOM AMOUNT")

            HStack(spacing: 20) {
                // Minus
                Button { customAmount = max(50, customAmount - 50) } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .foregroundStyle(Color.kalPrimary)
                        .background(Color.kalInput, in: Circle())
                }
                .buttonStyle(.plain)

                // Amount display
                VStack(spacing: 0) {
                    Text("\(customAmount)")
                        .font(.system(size: 38, weight: .heavy)).tracking(-1.5)
                        .foregroundStyle(Color.kalPrimary)
                        .contentTransition(.numericText(value: Double(customAmount)))
                        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: customAmount)
                    Text("ml")
                        .font(.system(size: 12, weight: .semibold)).tracking(0.4)
                        .foregroundStyle(Color.kalTertiary)
                }
                .frame(minWidth: 90)

                // Plus
                Button { customAmount = customAmount + 50 } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .foregroundStyle(.white)
                        .background(WaterStyle.cyan, in: Circle())
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .kalshiCard()
    }

    private let sources: [(String, String)] = [
        ("water",  "Water"),
        ("coffee", "Coffee"),
        ("tea",    "Tea"),
        ("juice",  "Juice"),
        ("soda",   "Soda"),
        ("other",  "Other")
    ]

    private var sourceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            eyebrow("SOURCE")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(sources, id: \.0) { (val, lbl) in
                    Button { selectedSource = val; UIImpactFeedbackGenerator(style: .light).impactOccurred() } label: {
                        VStack(spacing: 4) {
                            Image(systemName: sourceIcon(val))
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(selectedSource == val ? .white : WaterStyle.cyanDark)
                            Text(lbl)
                                .font(.system(size: 10, weight: .semibold)).tracking(0.2)
                                .foregroundStyle(selectedSource == val ? .white : Color.kalMuted)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(selectedSource == val ? WaterStyle.cyan : Color.kalInput,
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.14), value: selectedSource)
                }
            }
        }
        .padding(16)
        .kalshiCard()
    }

    // MARK: ═══════════════════════════════════════════════════════
    // TRENDS TAB
    // ════════════════════════════════════════════════════════════

    private var trendsTab: some View {
        VStack(spacing: 14) {
            intakeChartCard
            sourceBreakdownCard
            allTimeStatsCard
        }
    }

    @ViewBuilder
    private var intakeChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                eyebrow("INTAKE — LAST 7 DAYS")
                Spacer()
                Text("Goal: \(formatMl(goalMl))")
                    .font(.system(size: 10, weight: .medium)).foregroundStyle(Color.kalTertiary)
            }

            Chart {
                // Goal rule mark
                RuleMark(y: .value("Goal", goalMl))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .foregroundStyle(WaterStyle.cyan.opacity(0.5))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Goal").font(.system(size: 9, weight: .semibold)).foregroundStyle(WaterStyle.cyan)
                    }

                ForEach(Array(last7Days.enumerated()), id: \.offset) { i, day in
                    let hitGoal = day.ml >= goalMl
                    BarMark(
                        x: .value("Day", day.label),
                        y: .value("ml",  day.ml)
                    )
                    .foregroundStyle(
                        hitGoal
                            ? LinearGradient(colors: [WaterStyle.cyan, WaterStyle.cyanDark],
                                             startPoint: .top, endPoint: .bottom)
                            : LinearGradient(colors: [Color.kalDivider, Color.kalInput],
                                             startPoint: .top, endPoint: .bottom)
                    )
                    .cornerRadius(6)
                }
            }
            .frame(height: 180)
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine().foregroundStyle(Color.kalDivider)
                    AxisValueLabel()
                        .font(.system(size: 9)).foregroundStyle(Color.kalTertiary)
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.system(size: 10, weight: .medium)).foregroundStyle(Color.kalMuted)
                }
            }
        }
        .padding(16)
        .kalshiCard()
    }

    private var sourceBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            eyebrow("SOURCE BREAKDOWN")

            if sourceBreakdown.isEmpty {
                emptyState(icon: "chart.bar", message: "Log water to see source breakdown")
            } else {
                ForEach(sourceBreakdown, id: \.source) { item in
                    VStack(spacing: 4) {
                        HStack {
                            Image(systemName: sourceIcon(item.source))
                                .font(.system(size: 11)).foregroundStyle(WaterStyle.cyanDark)
                            Text(sourceLabel(item.source))
                                .font(.system(size: 12, weight: .medium)).foregroundStyle(Color.kalPrimary)
                            Spacer()
                            Text("\(item.pct)%")
                                .font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.kalMuted)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.kalDivider).frame(height: 5)
                                Capsule()
                                    .fill(LinearGradient(colors: [WaterStyle.cyan, WaterStyle.cyanDark],
                                                         startPoint: .leading, endPoint: .trailing))
                                    .frame(width: geo.size.width * CGFloat(item.pct) / 100, height: 5)
                                    .animation(.spring(duration: 0.5, bounce: 0.1), value: item.pct)
                            }
                        }
                        .frame(height: 5)
                    }
                }
            }
        }
        .padding(16)
        .kalshiCard()
    }

    private var allTimeStatsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            eyebrow("ALL-TIME STATS").padding(.bottom, 10)

            statRow("Total Logged",    value: String(format: "%.1fL", totalLifetimeL), accent: false)
            Divider()
            statRow("Total Entries",   value: "\(allLogs.count)",                      accent: false)
            Divider()
            statRow("Current Streak",  value: "\(streak)d",                            accent: true)
            Divider()
            statRow("Best Streak",     value: "\(bestStreak)d",                        accent: false)
        }
        .padding(16)
        .kalshiCard()
    }

    private func statRow(_ label: String, value: String, accent: Bool) -> some View {
        HStack {
            Text(label).font(.system(size: 13, weight: .medium)).foregroundStyle(Color.kalMuted)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .bold)).tracking(-0.3)
                .foregroundStyle(accent ? WaterStyle.cyan : Color.kalPrimary)
        }
        .padding(.vertical, 9)
    }

    // MARK: ═══════════════════════════════════════════════════════
    // MILESTONES TAB
    // ════════════════════════════════════════════════════════════

    private var milestonesTab: some View {
        VStack(spacing: 10) {
            ForEach(milestones) { milestone in
                milestoneCard(milestone)
            }
        }
    }

    private func milestoneCard(_ m: WaterMilestone) -> some View {
        HStack(spacing: 14) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(m.isAchieved ? WaterStyle.cyanBg : Color.kalInput)
                    .frame(width: 44, height: 44)
                Image(systemName: m.isAchieved ? "checkmark" : "lock.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(m.isAchieved ? WaterStyle.cyan : Color.kalTertiary)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(m.title)
                        .font(.system(size: 13, weight: .semibold)).tracking(-0.2)
                        .foregroundStyle(Color.kalPrimary)
                    Spacer()
                    Text(m.isAchieved ? "DONE" : "\(Int(m.achievedL * 10) / 10)L / \(Int(m.requiredL))L")
                        .font(.system(size: 9, weight: .bold)).tracking(0.5)
                        .foregroundStyle(m.isAchieved ? WaterStyle.cyanDark : Color.kalTertiary)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(m.isAchieved ? WaterStyle.cyanBg : Color.kalInput, in: Capsule())
                }

                Text(m.description)
                    .font(.system(size: 11, weight: .regular)).foregroundStyle(Color.kalMuted).lineLimit(1)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.kalDivider).frame(height: 5)
                        Capsule()
                            .fill(m.isAchieved
                                  ? LinearGradient(colors: [WaterStyle.cyan, WaterStyle.cyanDark],
                                                   startPoint: .leading, endPoint: .trailing)
                                  : LinearGradient(colors: [Color.kalDivider, Color.kalDivider],
                                                   startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * m.progress, height: 5)
                            .animation(.spring(duration: 0.6, bounce: 0.05), value: m.progress)
                    }
                }
                .frame(height: 5)

                Text("\(Int(m.progress * 100))%")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.kalTertiary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(m.isAchieved
                      ? LinearGradient(colors: [WaterStyle.cyanBg, Color.kalSurface],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                      : LinearGradient(colors: [Color.kalSurface, Color.kalSurface],
                                       startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(m.isAchieved ? WaterStyle.cyan.opacity(0.2) : Color.kalBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Log Sheet

    private var logSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    customAmountCard
                    sourceCard
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        addLog(ml: customAmount, source: selectedSource)
                        showLogSheet = false
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "drop.fill").font(.system(size: 13))
                            Text("Log \(formatMl(customAmount))")
                                .font(.system(size: 14, weight: .semibold)).tracking(-0.3)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(WaterStyle.cyan, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 16)
            }
            .background(Color.kalBackground)
            .navigationTitle("Log Water")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { showLogSheet = false }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.kalMuted)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Shared Helpers

    @ViewBuilder
    private func eyebrow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold)).tracking(0.8)
            .foregroundStyle(Color.kalTertiary)
    }

    @ViewBuilder
    private func emptyState(icon: String, message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 28)).foregroundStyle(Color.kalTertiary)
            Text(message).font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.kalTertiary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(28)
    }

    private func formatMl(_ ml: Int) -> String {
        ml >= 1000 ? String(format: "%.1fL", Double(ml)/1000) : "\(ml)ml"
    }

    private func sourceLabel(_ val: String) -> String {
        sources.first { $0.0 == val }?.1 ?? val.capitalized
    }

    private func sourceIcon(_ val: String) -> String {
        switch val {
        case "coffee": return "cup.and.saucer.fill"
        case "tea":    return "leaf.fill"
        case "juice":  return "flame.fill"
        case "soda":   return "bubbles.and.sparkles.fill"
        default:       return "drop.fill"
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let diff = Int(-date.timeIntervalSinceNow)
        if diff < 60 { return "just now" }
        if diff < 3600 { return "\(diff/60)m ago" }
        return "\(diff/3600)h ago"
    }

    private func addLog(ml: Int, source: String) {
        allLogs.insert(WaterLog(amountMl: ml, source: source, loggedAt: Date()), at: 0)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            todayMl = min(goalMl + 500, todayMl + ml)
            logSuccess = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { logSuccess = false }
        }
    }

    // MARK: - Mock Data

    static func mockLogs() -> [WaterLog] {
        let now = Date()
        return [
            WaterLog(amountMl: 500, source: "water",  loggedAt: now.addingTimeInterval(-1800)),
            WaterLog(amountMl: 250, source: "coffee",  loggedAt: now.addingTimeInterval(-5400)),
            WaterLog(amountMl: 350, source: "water",  loggedAt: now.addingTimeInterval(-10800)),
            WaterLog(amountMl: 250, source: "tea",    loggedAt: Calendar.current.date(byAdding: .day, value: -1, to: now)!),
            WaterLog(amountMl: 700, source: "water",  loggedAt: Calendar.current.date(byAdding: .day, value: -1, to: now)!),
            WaterLog(amountMl: 500, source: "juice",  loggedAt: Calendar.current.date(byAdding: .day, value: -2, to: now)!),
            WaterLog(amountMl: 300, source: "water",  loggedAt: Calendar.current.date(byAdding: .day, value: -3, to: now)!),
            WaterLog(amountMl: 1000, source: "water", loggedAt: Calendar.current.date(byAdding: .day, value: -4, to: now)!),
            WaterLog(amountMl: 400, source: "soda",   loggedAt: Calendar.current.date(byAdding: .day, value: -5, to: now)!),
            WaterLog(amountMl: 800, source: "water",  loggedAt: Calendar.current.date(byAdding: .day, value: -6, to: now)!),
        ]
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        WaterTrackerView()
    }
}
