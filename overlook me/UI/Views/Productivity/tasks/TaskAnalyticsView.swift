import SwiftUI

struct TaskAnalyticsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.injected) private var container

    private var tasks: [Task] { container.appState.state.tasks.tasks }

    private var totalCount: Int { tasks.count }
    private var activeCount: Int { tasks.filter { $0.status != .completed && $0.status != .cancelled }.count }
    private var completedCount: Int { tasks.filter { $0.status == .completed }.count }
    private var overdueCount: Int { tasks.filter { $0.isOverdue }.count }
    private var inProgressCount: Int { tasks.filter { $0.status == .inProgress }.count }
    private var onHoldCount: Int { tasks.filter { $0.status == .onHold }.count }
    private var cancelledCount: Int { tasks.filter { $0.status == .cancelled }.count }

    private var completionRate: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    private var criticalCount: Int { tasks.filter { $0.priority == .critical && $0.status != .completed }.count }
    private var highCount: Int { tasks.filter { $0.priority == .high && $0.status != .completed }.count }
    private var mediumCount: Int { tasks.filter { $0.priority == .medium && $0.status != .completed }.count }
    private var lowCount: Int { tasks.filter { $0.priority == .low && $0.status != .completed }.count }

    private var dueTodayCount: Int { tasks.filter { $0.isDueToday && $0.status != .completed }.count }
    private var scheduledTodayCount: Int { tasks.filter { $0.isScheduledToday }.count }
    private var avgProgress: Int {
        let active = tasks.filter { $0.status != .completed && $0.status != .cancelled }
        guard !active.isEmpty else { return 0 }
        return active.reduce(0) { $0 + $1.progressPercentage } / active.count
    }

    private var categoryCounts: [(String, Int)] {
        var dict: [String: Int] = [:]
        for t in tasks where t.status != .completed && t.status != .cancelled {
            dict[t.category ?? "Uncategorized", default: 0] += 1
        }
        return dict.sorted { $0.value > $1.value }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemGroupedBackground).ignoresSafeArea()
            gradientLayer

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    overviewHeader
                    completionCard
                    statusBreakdown
                    priorityBreakdown
                    categoryBreakdown
                    todaySection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 130)
                .padding(.bottom, 48)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        }
        .ignoresSafeArea(edges: .top)
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Overview Header

    private var overviewHeader: some View {
        HStack(spacing: 0) {
            headerStat(value: "\(totalCount)", label: "Total")
            headerStat(value: "\(activeCount)", label: "Active")
            headerStat(value: "\(completedCount)", label: "Done")
            headerStat(value: "\(overdueCount)", label: "Overdue")
        }
    }

    private func headerStat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(headerTextColor)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(headerTextColor.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }

    private var headerTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.9) : .white
    }

    // MARK: - Completion Ring Card

    private var completionCard: some View {
        HStack(spacing: 20) {
            ProgressRing(progress: completionRate, lineWidth: 10, color: .green)
                .frame(width: 70, height: 70)
                .overlay {
                    Text("\(Int(completionRate * 100))%")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)
                }

            VStack(alignment: .leading, spacing: 6) {
                Text("Completion Rate")
                    .font(.headline)
                Text("\(completedCount) of \(totalCount) tasks done")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.green.opacity(0.15))
                        Capsule().fill(Color.green)
                            .frame(width: geo.size.width * completionRate)
                            .animation(.spring(response: 0.5), value: completionRate)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(16)
        .background(cardBg)
    }

    // MARK: - Status Breakdown

    private var statusBreakdown: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Status")
            VStack(spacing: 8) {
                statusRow("In Progress", count: inProgressCount, icon: "arrow.triangle.2.circlepath", color: .blue)
                statusRow("On Hold", count: onHoldCount, icon: "pause.circle.fill", color: .orange)
                statusRow("Cancelled", count: cancelledCount, icon: "xmark.circle.fill", color: .red)
                statusRow("Avg Progress", count: avgProgress, icon: "chart.bar.fill", color: .purple, suffix: "%")
            }
            .padding(16)
            .background(cardBg)
        }
    }

    private func statusRow(_ label: String, count: Int, icon: String, color: Color, suffix: String = "") -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(color).frame(width: 20)
            Text(label).font(.subheadline)
            Spacer()
            Text("\(count)\(suffix)")
                .font(.subheadline.bold()).monospacedDigit()
                .foregroundStyle(count > 0 ? .primary : .tertiary)
        }
    }

    // MARK: - Priority

    private var priorityBreakdown: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Priority")
            HStack(spacing: 10) {
                priorityPill("Critical", count: criticalCount, color: .red)
                priorityPill("High", count: highCount, color: .orange)
                priorityPill("Medium", count: mediumCount, color: .blue)
                priorityPill("Low", count: lowCount, color: .gray)
            }
        }
    }

    private func priorityPill(_ label: String, count: Int, color: Color) -> some View {
        VStack(spacing: 6) {
            Text("\(count)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .contentTransition(.numericText(value: Double(count)))
            Text(label)
                .font(.caption2.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .foregroundStyle(count > 0 ? color : Color(.tertiaryLabel))
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AnalyticsPalette.cardBackground(for: colorScheme))
                .shadow(color: AnalyticsPalette.cardShadow(for: colorScheme), radius: 4, y: 2)
        )
    }

    // MARK: - Categories

    @ViewBuilder
    private var categoryBreakdown: some View {
        if !categoryCounts.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle("Categories")
                VStack(spacing: 8) {
                    ForEach(categoryCounts.prefix(8), id: \.0) { cat, count in
                        HStack(spacing: 12) {
                            Image(systemName: "folder.fill").foregroundStyle(.purple).frame(width: 20)
                            Text(cat).font(.subheadline)
                            Spacer()
                            Text("\(count)").font(.subheadline.bold()).monospacedDigit()
                        }
                    }
                }
                .padding(16)
                .background(cardBg)
            }
        }
    }

    // MARK: - Today

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Today")
            HStack(spacing: 10) {
                todayCard(icon: "calendar.badge.exclamationmark", label: "Due Today", count: dueTodayCount, color: dueTodayCount > 0 ? .red : .secondary)
                todayCard(icon: "calendar", label: "Scheduled", count: scheduledTodayCount, color: .blue)
            }
        }
    }

    private func todayCard(icon: String, label: String, count: Int, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.title3).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(count)").font(.title3.bold()).contentTransition(.numericText(value: Double(count)))
                Text(label).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(cardBg)
    }

    // MARK: - Helpers

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.bold())
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.leading, 4)
    }

    private var cardBg: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(AnalyticsPalette.cardBackground(for: colorScheme))
            .shadow(color: AnalyticsPalette.cardShadow(for: colorScheme), radius: 5, y: 3)
    }

    // MARK: - Gradient

    private var gradientLayer: some View {
        VStack(spacing: 0) {
            AnalyticsPalette.headerGradient(for: colorScheme)
                .frame(height: 280)
                .overlay(AnalyticsPalette.highlightGradient(for: colorScheme))
                .overlay(AnalyticsPalette.glossOverlay(for: colorScheme))
                .overlay(alignment: .bottom) {
                    AnalyticsPalette.fadeOverlay(for: colorScheme).frame(height: 98)
                }
                .frame(maxWidth: .infinity)
            Spacer()
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

// MARK: - Palette

private enum AnalyticsPalette {
    private static let teal = Color(uiColor: .systemTeal).opacity(0.85)
    private static let cyan = Color(uiColor: .systemCyan).opacity(0.75)
    private static let indigo = Color(uiColor: .systemIndigo).opacity(0.65)
    private static let purple = Color(uiColor: .systemPurple).opacity(0.55)

    static func headerGradient(for cs: ColorScheme) -> LinearGradient {
        LinearGradient(colors: stops(for: cs), startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static func highlightGradient(for cs: ColorScheme) -> LinearGradient {
        let lo = cs == .dark ? 0.18 : 0.45; let to = cs == .dark ? 0.05 : 0.15
        return LinearGradient(colors: [.white.opacity(lo), .white.opacity(to), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static func glossOverlay(for cs: ColorScheme) -> some View {
        let oo = cs == .dark ? 0.28 : 0.6; let go = cs == .dark ? 0.2 : 0.45
        return ZStack {
            RadialGradient(colors: [.white.opacity(go), .white.opacity(0.08), .clear], center: .topLeading, startRadius: 24, endRadius: 420)
            LinearGradient(colors: [.white.opacity(cs == .dark ? 0.2 : 0.35), .white.opacity(cs == .dark ? 0.04 : 0.05), .clear], startPoint: .top, endPoint: .bottom)
        }.blendMode(cs == .dark ? .plusLighter : .screen).opacity(oo)
    }
    static func fadeOverlay(for cs: ColorScheme) -> LinearGradient {
        LinearGradient(colors: [.clear, Color(.systemGroupedBackground)], startPoint: .top, endPoint: .bottom)
    }
    static func cardBackground(for cs: ColorScheme) -> Color {
        cs == .dark ? Color(uiColor: .secondarySystemBackground) : Color(.systemBackground)
    }
    static func cardShadow(for cs: ColorScheme) -> Color {
        .black.opacity(cs == .dark ? 0.45 : 0.08)
    }
    private static func stops(for cs: ColorScheme) -> [Color] {
        cs == .dark ? [teal.opacity(0.65), cyan.opacity(0.5), indigo.opacity(0.45), purple.opacity(0.4)] : [teal, cyan, indigo, purple]
    }
}
