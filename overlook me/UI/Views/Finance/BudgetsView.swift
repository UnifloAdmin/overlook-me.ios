import SwiftUI
import Charts
import Observation

// MARK: - Tab

enum BudgetTab: Hashable {
    case overview
    case detail(Int)
}

// MARK: - Attention Series (multi-budget overview chart)

struct AttentionSeries: Identifiable {
    let id: String
    let budgetId: Int
    let name: String
    let isProjected: Bool
    let color: Color
    let points: [(date: Date, amount: Double)]
}

// MARK: - View Model

@Observable
@MainActor
final class BudgetsViewModel {
    var budgets: [BudgetProgressDTO] = []
    var alerts: [BudgetAlertDTO] = []
    var snapshots: [Int: [BudgetDailySnapshotDTO]] = [:]

    var selectedTab: BudgetTab = .overview
    var bucketTransactions: [TransactionDTO] = []
    var txnPage = 1
    var txnTotalPages = 1
    var txnTotalCount = 0

    var isLoading = false
    var isLoadingTxns = false
    var errorMessage: String?
    var showCreateSheet = false

    private let api = BudgetsAPI(client: AppAPIClient.live())
    private let txnAPI = TransactionsAPI(client: AppAPIClient.live())
    private let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withFullDate]; return f
    }()

    // MARK: Computed

    var unreadAlerts: [BudgetAlertDTO] { alerts.filter { !$0.isRead } }
    var totalBudgeted: Double  { budgets.reduce(0) { $0 + $1.budgetAmount } }
    var totalSpent: Double     { budgets.reduce(0) { $0 + $1.spentAmount } }
    var totalRemaining: Double { budgets.reduce(0) { $0 + $1.remainingAmount } }
    var overallPercent: Double { totalBudgeted > 0 ? (totalSpent / totalBudgeted) * 100 : 0 }
    var onTrackCount: Int { budgets.filter { $0.status == .onTrack }.count }
    var warningCount: Int { budgets.filter { $0.status == .warning }.count }
    var overCount: Int    { budgets.filter { $0.status == .over }.count }

    var attentionBudgets: [BudgetProgressDTO] {
        budgets.filter { $0.status == .warning || $0.status == .over }
    }

    var selectedBudget: BudgetProgressDTO? {
        guard case .detail(let id) = selectedTab else { return nil }
        return budgets.first { $0.budgetId == id }
    }

    var attentionSeries: [AttentionSeries] {
        var result: [AttentionSeries] = []
        let colors = attentionLineColors()
        for (i, budget) in budgets.enumerated() {
            guard let snaps = snapshots[budget.budgetId], !snaps.isEmpty else { continue }
            let color = colors[i % colors.count]
            let actual = snaps.compactMap { s -> (Date, Double)? in
                guard let d = parseDate(s.date) else { return nil }
                return (d, s.cumulativeAmount)
            }.sorted { $0.0 < $1.0 }
            if !actual.isEmpty {
                result.append(AttentionSeries(
                    id: "\(budget.budgetId)-actual",
                    budgetId: budget.budgetId,
                    name: budget.budgetName,
                    isProjected: false,
                    color: color,
                    points: actual
                ))
            }
        }
        return result
    }

    private func attentionLineColors() -> [Color] {
        budgets.map { budget in
            switch budget.status {
            case .over:    return Color.kRed
            case .warning: return Color(red: 0.976, green: 0.451, blue: 0.086)
            case .onTrack: return Color.kPrimary
            }
        }
    }

    // MARK: Load

    func load(userId: String) async {
        guard !userId.isEmpty else { return }
        isLoading = true
        errorMessage = nil

        do {
            budgets = try await api.getBudgetProgress(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }

        async let a: () = loadAlerts(userId: userId)
        async let s: () = loadAllSnapshots()
        _ = await (a, s)

        isLoading = false
    }

    private func loadAlerts(userId: String) async {
        do { alerts = try await api.getBudgetAlerts(userId: userId) } catch { }
    }

    func loadAllSnapshots() async {
        await withTaskGroup(of: Void.self) { group in
            for budget in budgets {
                let bid = budget.budgetId
                guard snapshots[bid] == nil else { continue }
                group.addTask { [weak self] in
                    guard let self else { return }
                    do {
                        let res = try await self.api.getBudgetSnapshots(budgetId: bid)
                        await MainActor.run { self.snapshots[bid] = res.snapshots }
                    } catch {
                        await MainActor.run { self.snapshots[bid] = [] }
                    }
                }
            }
        }
    }

    func loadBudgetTransactions(budget: BudgetProgressDTO, page: Int = 1, userId: String) async {
        isLoadingTxns = true
        do {
            var query: [String: String?] = [
                "userId": userId,
                "type": "all",
                "startDate": String(budget.periodStartDate.prefix(10)),
                "endDate": String(budget.periodEndDate.prefix(10)),
                "page": String(page),
                "pageSize": "10",
                "sortBy": "date",
                "sortOrder": "desc"
            ]
            if let cid = budget.categoryId { query["categoryId"] = String(cid) }
            let response = try await txnAPI.getAllTransactions(
                userId: userId,
                page: page,
                pageSize: 10,
                startDate: String(budget.periodStartDate.prefix(10)),
                endDate: String(budget.periodEndDate.prefix(10)),
                sortBy: "date",
                sortOrder: "desc"
            )
            let raw = response.transactions ?? []
            bucketTransactions = raw.filter { $0.amount > 0 }
            txnPage = response.pagination?.currentPage ?? page
            txnTotalPages = response.pagination?.totalPages ?? 1
            txnTotalCount = response.pagination?.totalItems ?? bucketTransactions.count
        } catch {
            bucketTransactions = []
        }
        isLoadingTxns = false
    }

    func selectBudget(_ id: Int, userId: String) {
        selectedTab = .detail(id)
        bucketTransactions = []
        txnPage = 1
        txnTotalPages = 1
        txnTotalCount = 0
        if let budget = budgets.first(where: { $0.budgetId == id }) {
            _Concurrency.Task { await loadBudgetTransactions(budget: budget, page: 1, userId: userId) }
        }
    }

    func goToTxnPage(_ page: Int, userId: String) async {
        guard let budget = selectedBudget else { return }
        await loadBudgetTransactions(budget: budget, page: page, userId: userId)
    }

    func deleteBudget(budgetId: Int, userId: String) async {
        do {
            _ = try await api.deleteBudget(budgetId: budgetId, userId: userId)
            budgets.removeAll { $0.budgetId == budgetId }
            selectedTab = .overview
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func dismissAlert(id: Int, userId: String) async {
        do {
            _ = try await api.markAlertAsRead(alertId: id, userId: userId)
            alerts.removeAll { $0.id == id }
        } catch { }
    }

    func dismissAllAlerts(userId: String) async {
        do {
            _ = try await api.markAllAlertsAsRead(userId: userId)
            alerts.removeAll()
        } catch { }
    }

    func parseDate(_ str: String) -> Date? {
        dateFormatter.date(from: String(str.prefix(10)))
    }
}

// MARK: - Main View

struct BudgetsView: View {
    @SwiftUI.Environment(\.injected) private var container: DIContainer
    @State private var viewModel = BudgetsViewModel()

    private var userId: String {
        container.appState.state.auth.user?.id ?? ""
    }

    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                loadingSkeleton
            } else if viewModel.budgets.isEmpty {
                emptyState
            } else {
                budgetTabBar
                tabContent
            }
        }
        .scrollContentBackground(.hidden)
        .background(Kalshi.bg)
        .navigationTitle("Budgets")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.showCreateSheet = true
                } label: {
                    Label("New Budget", systemImage: "plus")
                        .font(.system(size: 14, weight: .semibold))
                }
            }
        }
        .task { await viewModel.load(userId: userId) }
        .refreshable { await viewModel.load(userId: userId) }
        .sheet(isPresented: $viewModel.showCreateSheet) {
            BudgetCreateView { await viewModel.load(userId: userId) }
        }
    }

    // MARK: - Tab Bar

    private var budgetTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                tabPill(tab: .overview, label: "Overview", percent: nil, status: nil)
                ForEach(viewModel.budgets) { budget in
                    tabPill(
                        tab: .detail(budget.budgetId),
                        label: budget.budgetName,
                        percent: budget.percentageUsed,
                        status: budget.status
                    )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(Kalshi.bg)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.kBorder).frame(height: 1)
        }
    }

    private func tabPill(
        tab: BudgetTab,
        label: String,
        percent: Double?,
        status: BudgetProgressDTO.BudgetStatus?
    ) -> some View {
        let isActive = viewModel.selectedTab == tab
        return Button {
            withAnimation(Kalshi.micro) {
                if case .detail(let id) = tab {
                    viewModel.selectBudget(id, userId: userId)
                } else {
                    viewModel.selectedTab = .overview
                }
            }
        } label: {
            HStack(spacing: 5) {
                Text(label)
                    .font(.system(size: 12, weight: isActive ? .semibold : .medium))
                    .tracking(-0.1)
                    .lineLimit(1)

                if let pct = percent, let status {
                    Text("\(Int(pct))%")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(pctColor(status))
                }
            }
            .foregroundStyle(isActive ? Color.white : Color.kSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isActive ? Color.kPrimary : Color.kSurface, in: Capsule())
            .overlay(
                isActive ? nil : Capsule().stroke(Color.kBorderMedium, lineWidth: 1)
            )
        }
        .buttonStyle(KPressButtonStyle())
    }

    private func pctColor(_ status: BudgetProgressDTO.BudgetStatus) -> Color {
        switch status {
        case .onTrack: return Color.kGreen
        case .warning: return Color(red: 0.976, green: 0.451, blue: 0.086)
        case .over:    return Color.kRed
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch viewModel.selectedTab {
        case .overview:
            overviewContent
        case .detail:
            detailContent
        }
    }

    // MARK: - Loading / Empty

    private var loadingSkeleton: some View {
        VStack(spacing: 10) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.kDividerBg)
                    .frame(height: 88)
                    .shimmer()
            }
        }
        .padding(14)
        .padding(.top, 10)
    }

    private var emptyState: some View {
        KEmptyState(
            icon: "wallet.pass",
            title: "No budgets yet",
            message: "Set spending limits by category and track progress in real time.",
            ctaLabel: "Create Budget",
            ctaAction: { viewModel.showCreateSheet = true }
        )
        .padding(.top, 20)
    }
}

// MARK: - Overview Content

private extension BudgetsView {

    var overviewContent: some View {
        LazyVStack(spacing: 10) {
            bentoGrid
            if !viewModel.attentionBudgets.isEmpty && !viewModel.attentionSeries.isEmpty {
                attentionChartCard
            }
            alertsCard
        }
        .padding(.horizontal, 14)
        .padding(.top, 16)
        .padding(.bottom, 100)
        .background(Kalshi.bg)
    }

    // MARK: Bento grid

    var bentoGrid: some View {
        VStack(spacing: 8) {
            // Row 1: counts
            HStack(spacing: 8) {
                bentoCell(
                    eyebrow: "Total",
                    value: "\(viewModel.budgets.count)",
                    sub: "active",
                    accent: nil,
                    wide: false
                )
                bentoCell(
                    eyebrow: "On Track",
                    value: "\(viewModel.onTrackCount)",
                    sub: "within limits",
                    accent: Color.kGreen,
                    wide: false
                )
                bentoCell(
                    eyebrow: "Over Budget",
                    value: "\(viewModel.overCount)",
                    sub: viewModel.overCount > 0 ? "need attention" : "all good",
                    accent: viewModel.overCount > 0 ? Color.kRed : Color.kGreen,
                    wide: false
                )
            }

            // Row 2: money
            HStack(spacing: 8) {
                bentoMoneyCell(eyebrow: "Budgeted",  value: viewModel.totalBudgeted)
                bentoMoneyCell(eyebrow: "Spent",     value: viewModel.totalSpent,
                               isOver: viewModel.totalSpent > viewModel.totalBudgeted)
                bentoPctCell
            }
        }
    }

    func bentoCell(eyebrow: String, value: String, sub: String, accent: Color?, wide: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            KLabel(eyebrow)
            Text(value)
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .tracking(-1)
                .foregroundStyle(accent ?? Color.kPrimary)
                .contentTransition(.numericText())
            Text(sub)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.kTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.kSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.kBorder, lineWidth: 1))
    }

    func bentoMoneyCell(eyebrow: String, value: Double, isOver: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            KLabel(eyebrow)
            Text(formatCurrencyCompact(value))
                .font(.system(size: 18, weight: .bold))
                .tracking(-0.7)
                .foregroundStyle(isOver ? Color.kRed : Color.kPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.kSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.kBorder, lineWidth: 1))
    }

    var bentoPctCell: some View {
        VStack(alignment: .leading, spacing: 4) {
            KLabel("Remaining")
            Text(formatCurrencyCompact(viewModel.totalRemaining))
                .font(.system(size: 18, weight: .bold))
                .tracking(-0.7)
                .foregroundStyle(viewModel.totalRemaining < 0 ? Color.kRed : Color.kPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
            KProgressBar(
                ratio: min(viewModel.overallPercent / 100, 1.0),
                color: viewModel.overallPercent >= 100 ? Color.kRed : viewModel.overallPercent >= 80 ? Color(red: 0.976, green: 0.451, blue: 0.086) : Color.kGreen,
                height: 4
            )
            .padding(.top, 2)
            Text("\(Int(viewModel.overallPercent))% used")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color.kTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.kSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.kBorder, lineWidth: 1))
    }

    // MARK: Attention chart

    var attentionChartCard: some View {
        KCard(title: "Spending Overview", icon: "chart.line.uptrend.xyaxis") {
            VStack(alignment: .leading, spacing: 10) {
                // Legend
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(viewModel.attentionBudgets) { budget in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(attentionColor(budget))
                                    .frame(width: 6, height: 6)
                                Text(budget.budgetName)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(Color.kSecondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }

                Chart(viewModel.attentionSeries) { series in
                    ForEach(series.points, id: \.0) { point in
                        LineMark(
                            x: .value("Date", point.0),
                            y: .value("Amount", point.1),
                            series: .value("Budget", series.id)
                        )
                        .foregroundStyle(series.color)
                        .lineStyle(StrokeStyle(lineWidth: series.isProjected ? 1.5 : 2,
                                               lineCap: .round,
                                               dash: series.isProjected ? [4, 3] : []))
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3]))
                            .foregroundStyle(Color.kBorder)
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(formatCurrencyCompact(v))
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(Color.kTertiary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .font(.system(size: 9, weight: .medium))
                    }
                }
                .frame(height: 160)
            }
        }
    }

    func attentionColor(_ budget: BudgetProgressDTO) -> Color {
        switch budget.status {
        case .over:    return Color.kRed
        case .warning: return Color(red: 0.976, green: 0.451, blue: 0.086)
        case .onTrack: return Color.kPrimary
        }
    }

    // MARK: Alerts

    var alertsCard: some View {
        KCard(title: "Alerts", icon: "bell") {
            if viewModel.unreadAlerts.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.kGreen)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("All budgets on track")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.kPrimary)
                        Text("You're within limits across every category.")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.kTertiary)
                    }
                }
                .padding(.top, 4)
            } else {
                VStack(spacing: 0) {
                    HStack {
                        Text("\(viewModel.unreadAlerts.count) unread")
                            .kalshiSecondary()
                        Spacer()
                        Button {
                            _Concurrency.Task { await viewModel.dismissAllAlerts(userId: userId) }
                        } label: {
                            Text("Clear all")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.kTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, 8)

                    ForEach(viewModel.unreadAlerts.prefix(5)) { alert in
                        alertRow(alert)
                        if alert.id != viewModel.unreadAlerts.prefix(5).last?.id {
                            Rectangle().fill(Color.kBorder).frame(height: 1)
                        }
                    }
                }
            }
        }
    }

    func alertRow(_ alert: BudgetAlertDTO) -> some View {
        HStack(spacing: 10) {
            Image(systemName: alert.alertType == "Exceeded" || alert.alertType == "Critical"
                  ? "exclamationmark.circle.fill" : "exclamationmark.circle")
                .font(.system(size: 18))
                .foregroundStyle(alert.alertType == "Warning"
                    ? Color(red: 0.984, green: 0.749, blue: 0.141) : Color.kRed)

            VStack(alignment: .leading, spacing: 2) {
                Text(alert.message)
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(-0.1)
                    .foregroundStyle(Color.kPrimary)
                    .lineLimit(2)
                Text(formatAlertDate(alert.createdAt))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.kTertiary)
            }
            Spacer()
            Button {
                _Concurrency.Task { await viewModel.dismissAlert(id: alert.id, userId: userId) }
            } label: {
                Text("Dismiss")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.kTertiary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.kDividerBg, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
    }

    func formatAlertDate(_ str: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = f.date(from: str) ?? {
            f.formatOptions = [.withInternetDateTime]; return f.date(from: str)
        }() else { return str }
        return date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }

    func formatCurrencyCompact(_ value: Double) -> String {
        let abs = Swift.abs(value)
        let prefix = value < 0 ? "-" : ""
        if abs >= 10_000 { return "\(prefix)$\(String(format: "%.1f", abs / 1000))k" }
        return value.formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }
}

// MARK: - Detail Content

private extension BudgetsView {

    var detailContent: some View {
        Group {
            if let budget = viewModel.selectedBudget {
                LazyVStack(spacing: 10) {
                    budgetHeroCard(budget)
                    miniStatsCard(budget)
                    spendTrendCard(budget)
                    transactionsCard(budget)
                    footerRow(budget)
                }
                .padding(.horizontal, 14)
                .padding(.top, 16)
                .padding(.bottom, 100)
                .background(Kalshi.bg)
            }
        }
    }

    // MARK: Hero card

    func budgetHeroCard(_ b: BudgetProgressDTO) -> some View {
        KCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(b.budgetName)
                            .font(.system(size: 16, weight: .bold))
                            .tracking(-0.4)
                            .foregroundStyle(Color.kPrimary)

                        Text("\(b.categoryName ?? "All Spending") · \(b.period)")
                            .kalshiSecondary()
                    }
                    Spacer()
                    KStatusBadge(
                        text: statusLabel(b),
                        style: b.status == .onTrack ? .done : b.status == .warning ? .pending : .fail
                    )
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(formatCurrency(b.spentAmount))
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .tracking(-1)
                        .foregroundStyle(statusColor(b))

                    Text("/ \(formatCurrency(b.budgetAmount))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.kSecondary)

                    Spacer()

                    Text("\(Int(b.percentageUsed))%")
                        .font(.system(size: 18, weight: .bold))
                        .tracking(-0.6)
                        .foregroundStyle(statusColor(b))
                }

                KProgressBar(
                    ratio: min(b.percentageUsed / 100, 1.0),
                    color: statusColor(b),
                    height: 6
                )

                if let start = viewModel.parseDate(b.periodStartDate),
                   let end   = viewModel.parseDate(b.periodEndDate) {
                    let fmt = Date.FormatStyle().month(.abbreviated).day()
                    Text("Resets \(b.period.lowercased())  ·  \(start.formatted(fmt)) – \(end.formatted(fmt))")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.kTertiary)
                }
            }
        }
    }

    // MARK: Mini stats

    func miniStatsCard(_ b: BudgetProgressDTO) -> some View {
        KStatRow(items: [
            (label: "Days Left",  value: "\(b.daysRemaining)",                         color: Color.kPrimary),
            (label: "Daily Avg",  value: formatCurrencyCompact(b.dailyAverage),         color: Color.kPrimary),
            (label: "Suggested",  value: formatCurrencyCompact(b.recommendedDailySpend),color: Color.kPrimary),
            (label: "Remaining",  value: formatCurrencyCompact(b.remainingAmount),      color: b.remainingAmount >= 0 ? Color.kGreen : Color.kRed),
            (label: "Projected",  value: formatCurrencyCompact(b.projectedSpending),    color: b.projectedSpending > b.budgetAmount ? Color.kRed : Color.kPrimary)
        ])
    }

    // MARK: Spend trend chart

    func spendTrendCard(_ b: BudgetProgressDTO) -> some View {
        KCard(title: "Spend Trend", icon: "chart.line.uptrend.xyaxis") {
            let snaps = viewModel.snapshots[b.budgetId]

            Group {
                if snaps == nil {
                    ProgressView().frame(maxWidth: .infinity).frame(height: 150)
                } else if (snaps ?? []).isEmpty {
                    KEmptyState(icon: "chart.line.uptrend.xyaxis",
                                title: "No snapshot data",
                                message: "Daily spending data will appear here")
                } else {
                    trendChart(b, snaps: snaps ?? [])
                }
            }
        }
        .task { await viewModel.loadAllSnapshots() }
    }

    func trendChart(_ b: BudgetProgressDTO, snaps: [BudgetDailySnapshotDTO]) -> some View {
        let sorted = snaps.sorted { $0.date < $1.date }
        let actual: [(Date, Double)] = sorted.compactMap { s in
            guard let d = viewModel.parseDate(s.date) else { return nil }
            return (d, s.cumulativeAmount)
        }
        let ideal: [(Date, Double)] = buildIdealPace(b, count: sorted.count)
        let color = statusColor(b)

        return Chart {
            ForEach(ideal, id: \.0) { pt in
                LineMark(x: .value("Date", pt.0), y: .value("Ideal", pt.1), series: .value("S", "ideal"))
                    .foregroundStyle(Color.kBorderMedium)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .interpolationMethod(.linear)
            }
            ForEach(actual, id: \.0) { pt in
                AreaMark(x: .value("Date", pt.0), y: .value("Actual", pt.1))
                    .foregroundStyle(color.opacity(0.08))
                    .interpolationMethod(.catmullRom)
                LineMark(x: .value("Date", pt.0), y: .value("Actual", pt.1), series: .value("S", "actual"))
                    .foregroundStyle(color.opacity(0.85))
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                    .interpolationMethod(.catmullRom)
            }
        }
        .chartLegend(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3])).foregroundStyle(Color.kBorder)
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(formatCurrencyCompact(v)).font(.system(size: 9, weight: .medium)).foregroundStyle(Color.kTertiary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day()).font(.system(size: 9, weight: .medium))
            }
        }
        .frame(height: 160)
        .padding(.top, 4)
    }

    func buildIdealPace(_ b: BudgetProgressDTO, count: Int) -> [(Date, Double)] {
        guard let start = viewModel.parseDate(b.periodStartDate),
              let end   = viewModel.parseDate(b.periodEndDate) else { return [] }
        let totalDays = max(1.0, end.timeIntervalSince(start) / 86400)
        let today = min(Date(), end)
        let elapsed = today.timeIntervalSince(start) / 86400
        return [
            (start, 0),
            (today, b.budgetAmount * min(elapsed / totalDays, 1.0))
        ]
    }

    // MARK: Transactions

    func transactionsCard(_ b: BudgetProgressDTO) -> some View {
        KCard(title: b.categoryName ?? "All Spending", icon: "list.bullet") {
            VStack(spacing: 0) {
                HStack {
                    Text("\(viewModel.txnTotalCount) transactions")
                        .kalshiSecondary()
                    Spacer()
                    if viewModel.isLoadingTxns {
                        ProgressView().scaleEffect(0.7)
                    }
                }
                .padding(.bottom, 8)

                if viewModel.bucketTransactions.isEmpty && !viewModel.isLoadingTxns {
                    KEmptyState(icon: "arrow.left.arrow.right",
                                title: "No expenses",
                                message: "No expenses in this budget for the current period.")
                } else {
                    VStack(spacing: 0) {
                        ForEach(viewModel.bucketTransactions) { txn in
                            txnRow(txn)
                            if txn.id != viewModel.bucketTransactions.last?.id {
                                Rectangle().fill(Color.kBorder).frame(height: 1)
                            }
                        }
                    }

                    if viewModel.txnTotalPages > 1 {
                        paginationRow(b)
                    }
                }
            }
        }
    }

    func txnRow(_ txn: TransactionDTO) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(txn.merchantName ?? txn.name ?? "Transaction")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(-0.1)
                    .foregroundStyle(Color.kPrimary)
                    .lineLimit(1)
                Text(txn.category ?? "Uncategorized")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.kTertiary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatCurrency(txn.amount))
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(-0.1)
                    .foregroundStyle(Color.kPrimary)
                Text(shortDate(txn.date))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.kTertiary)
            }
        }
        .padding(.vertical, 8)
    }

    func paginationRow(_ b: BudgetProgressDTO) -> some View {
        HStack(spacing: 6) {
            Button {
                guard viewModel.txnPage > 1 else { return }
                _Concurrency.Task { await viewModel.goToTxnPage(viewModel.txnPage - 1, userId: userId) }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(viewModel.txnPage == 1 ? Color.kTertiary : Color.kPrimary)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.txnPage == 1)

            Text("Page \(viewModel.txnPage) of \(viewModel.txnTotalPages)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.kSecondary)

            Button {
                guard viewModel.txnPage < viewModel.txnTotalPages else { return }
                _Concurrency.Task { await viewModel.goToTxnPage(viewModel.txnPage + 1, userId: userId) }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(viewModel.txnPage == viewModel.txnTotalPages ? Color.kTertiary : Color.kPrimary)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.txnPage == viewModel.txnTotalPages)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }

    // MARK: Footer

    func footerRow(_ b: BudgetProgressDTO) -> some View {
        HStack {
            if let start = viewModel.parseDate(b.periodStartDate),
               let end   = viewModel.parseDate(b.periodEndDate) {
                let fmt = Date.FormatStyle().month(.abbreviated).day()
                Text("Resets \(b.period.lowercased())  ·  \(start.formatted(fmt)) – \(end.formatted(fmt))")
                    .kalshiSecondary()
            }
            Spacer()
            Button {
                _Concurrency.Task { await viewModel.deleteBudget(budgetId: b.budgetId, userId: userId) }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.kRed)
                    .padding(8)
                    .background(Color.kRedBg, in: Circle())
            }
            .buttonStyle(KPressButtonStyle())
        }
        .padding(.horizontal, 4)
    }

    // MARK: Helpers

    func statusLabel(_ b: BudgetProgressDTO) -> String {
        switch b.status { case .onTrack: "On Track"; case .warning: "Warning"; case .over: "Over Budget" }
    }

    func statusColor(_ b: BudgetProgressDTO) -> Color {
        switch b.status {
        case .onTrack: return Color.kGreen
        case .warning: return Color(red: 0.976, green: 0.451, blue: 0.086)
        case .over:    return Color.kRed
        }
    }

    func formatCurrency(_ value: Double) -> String {
        value.formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }

    func shortDate(_ str: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        guard let date = f.date(from: String(str.prefix(10))) else { return str }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}

// MARK: - Shimmer

private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [.clear, Color.white.opacity(0.45), .clear]),
                    startPoint: .init(x: phase, y: 0.5),
                    endPoint: .init(x: phase + 0.4, y: 0.5)
                )
                .animation(.linear(duration: 1.2).repeatForever(autoreverses: false), value: phase)
            )
            .onAppear { phase = 1.5 }
    }
}

private extension View {
    func shimmer() -> some View { modifier(ShimmerModifier()) }
}

// MARK: - Preview

#Preview {
    BudgetsView()
        .environment(\.injected, .previewAuthenticated)
}
