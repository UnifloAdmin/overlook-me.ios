import SwiftUI

struct TaskAnalyticsView: View {
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
            TasksKalshiStyle.pageBackground.ignoresSafeArea()

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
                .padding(.top, 12)
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
                .font(.system(size: 23, weight: .bold))
                .foregroundStyle(TasksKalshiStyle.primaryText)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .kerning(0.6)
                .foregroundStyle(TasksKalshiStyle.tertiaryText)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Completion Ring Card

    private var completionCard: some View {
        HStack(spacing: 20) {
            ProgressRing(progress: completionRate, lineWidth: 8, color: TasksKalshiStyle.done)
                .frame(width: 70, height: 70)
                .overlay {
                    Text("\(Int(completionRate * 100))%")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(TasksKalshiStyle.done)
                }

            VStack(alignment: .leading, spacing: 6) {
                Text("Completion Rate")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(TasksKalshiStyle.primaryText)
                Text("\(completedCount) of \(totalCount) tasks done")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(TasksKalshiStyle.secondaryText)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(TasksKalshiStyle.surfaceMuted)
                        Capsule().fill(TasksKalshiStyle.done)
                            .frame(width: geo.size.width * completionRate)
                            .animation(.easeInOut(duration: 0.15), value: completionRate)
                    }
                }
                .frame(height: 7)
            }
        }
        .padding(14)
        .tasksDataCard()
    }

    // MARK: - Status Breakdown

    private var statusBreakdown: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Status")
            VStack(spacing: 8) {
                statusRow("In Progress", count: inProgressCount, icon: "arrow.triangle.2.circlepath", color: TasksKalshiStyle.today)
                statusRow("On Hold", count: onHoldCount, icon: "pause.circle.fill", color: TasksKalshiStyle.warning)
                statusRow("Cancelled", count: cancelledCount, icon: "xmark.circle.fill", color: TasksKalshiStyle.danger)
                statusRow("Avg Progress", count: avgProgress, icon: "chart.bar.fill", color: TasksKalshiStyle.secondaryText, suffix: "%")
            }
            .padding(14)
            .tasksDataCard()
        }
    }

    private func statusRow(_ label: String, count: Int, icon: String, color: Color, suffix: String = "") -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(color).frame(width: 20)
            Text(label).font(.system(size: 12, weight: .semibold)).foregroundStyle(TasksKalshiStyle.primaryText)
            Spacer()
            Text("\(count)\(suffix)")
                .font(.system(size: 12, weight: .semibold)).monospacedDigit()
                .foregroundStyle(count > 0 ? TasksKalshiStyle.primaryText : TasksKalshiStyle.tertiaryText)
        }
    }

    // MARK: - Priority

    private var priorityBreakdown: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Priority")
            HStack(spacing: 10) {
                priorityPill("Critical", count: criticalCount, color: TasksKalshiStyle.danger)
                priorityPill("High", count: highCount, color: TasksKalshiStyle.warning)
                priorityPill("Medium", count: mediumCount, color: TasksKalshiStyle.today)
                priorityPill("Low", count: lowCount, color: TasksKalshiStyle.secondaryText)
            }
        }
    }

    private func priorityPill(_ label: String, count: Int, color: Color) -> some View {
        VStack(spacing: 6) {
            Text("\(count)")
                .font(.system(size: 23, weight: .bold))
                .contentTransition(.numericText(value: Double(count)))
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .kerning(0.6)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .foregroundStyle(count > 0 ? color : TasksKalshiStyle.tertiaryText)
        .tasksDataCard()
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
                            Image(systemName: "folder.fill").foregroundStyle(TasksKalshiStyle.secondaryText).frame(width: 20)
                            Text(cat).font(.system(size: 12, weight: .semibold)).foregroundStyle(TasksKalshiStyle.primaryText)
                            Spacer()
                            Text("\(count)").font(.system(size: 12, weight: .semibold)).monospacedDigit()
                        }
                    }
                }
                .padding(14)
                .tasksDataCard()
            }
        }
    }

    // MARK: - Today

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Today")
            HStack(spacing: 10) {
                todayCard(icon: "calendar.badge.exclamationmark", label: "Due Today", count: dueTodayCount, color: dueTodayCount > 0 ? TasksKalshiStyle.danger : TasksKalshiStyle.secondaryText)
                todayCard(icon: "calendar", label: "Scheduled", count: scheduledTodayCount, color: TasksKalshiStyle.today)
            }
        }
    }

    private func todayCard(icon: String, label: String, count: Int, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.title3).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(count)").font(.system(size: 23, weight: .bold)).contentTransition(.numericText(value: Double(count)))
                Text(label).font(.system(size: 10, weight: .semibold)).foregroundStyle(TasksKalshiStyle.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .tasksDataCard()
    }

    // MARK: - Helpers

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(TasksKalshiStyle.secondaryText)
            .kerning(0.6)
            .textCase(.uppercase)
            .padding(.leading, 4)
    }
}
