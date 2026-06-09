import SwiftUI
import Observation

// MARK: - Transactions View

struct TransactionsView: View {
    @SwiftUI.Environment(\.injected) private var container: DIContainer
    @Bindable var viewModel: TransactionsViewModel
    let tab: TransactionTab

    private var userId: String {
        container.appState.state.auth.user?.id ?? ""
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerView

                Group {
                    switch tab {
                    case .analytics:
                        TransactionsAnalyticsView(viewModel: viewModel)
                    case .ledger:
                        TransactionsLedgerView(viewModel: viewModel)
                    case .merchants:
                        TransactionsMerchantsView(viewModel: viewModel)
                    case .search:
                        TransactionsSearchView(viewModel: viewModel)
                    }
                }
                .frame(maxWidth: .infinity)
                .background(Color.kSurface)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.kSurface)
        .navigationTitle("Transactions")
        .task { await loadDataForTab() }
        .onChange(of: viewModel.viewMode) { _, _ in reloadForCurrentTab() }
        .onChange(of: viewModel.customStart) { _, _ in
            if viewModel.viewMode == .custom { reloadForCurrentTab() }
        }
        .onChange(of: viewModel.customEnd) { _, _ in
            if viewModel.viewMode == .custom { reloadForCurrentTab() }
        }
        .refreshable { await refreshForTab() }
        .tabBarConfig(.transactions)
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 0) {
            TransactionsPeriodPicker(viewModel: viewModel)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 10)

            // Summary metrics row
            TransactionsSummaryStrip(viewModel: viewModel)
        }
    }

    private func loadDataForTab() async {
        switch tab {
        case .analytics:
            await viewModel.loadInitialData(userId: userId)
        case .ledger:
            if viewModel.ledgerDayGroups.isEmpty {
                await viewModel.loadLedgerSummary(userId: userId)
            }
        case .merchants:
            if viewModel.merchantSummaries.isEmpty {
                await viewModel.loadMerchants(userId: userId)
            }
        case .search:
            break
        }
    }

    private func reloadForCurrentTab() {
        let uid = userId
        let vm = viewModel
        let currentTab = tab
        _Concurrency.Task {
            switch currentTab {
            case .analytics: await vm.loadAnalytics(userId: uid)
            case .ledger: await vm.loadLedgerSummary(userId: uid)
            case .merchants: await vm.loadMerchants(userId: uid)
            case .search: break
            }
        }
    }

    private func refreshForTab() async {
        switch tab {
        case .analytics: await viewModel.loadInitialData(userId: userId)
        case .ledger: await viewModel.loadLedgerSummary(userId: userId)
        case .merchants: await viewModel.loadMerchants(userId: userId)
        case .search: break
        }
    }
}

// MARK: - Period Picker

struct TransactionsPeriodPicker: View {
    @Bindable var viewModel: TransactionsViewModel
    @State private var selected: PeriodPreset = .week
    @State private var showSheet = false

    var body: some View {
        Button { showSheet = true } label: {
            HStack(spacing: 8) {
                // Calendar icon
                Image(systemName: "calendar")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))

                // Date range
                Text(rangeLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(-0.2)
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.15), value: rangeLabel)

                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                Capsule().fill(.ultraThinMaterial)
                // Top-edge glass highlight
                Capsule().fill(
                    LinearGradient(
                        colors: [.white.opacity(0.18), .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
            }
            .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 4)
        }
        .buttonStyle(KPressButtonStyle())
        .sheet(isPresented: $showSheet) {
            PeriodPickerSheet(viewModel: viewModel, selected: $selected)
                .presentationDetents([.height(400)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
        }
        .onAppear { applyPreset(.week) }
    }

    private var rangeLabel: String {
        let fmt = Date.FormatStyle().month(.abbreviated).day()
        return "\(viewModel.customStart.formatted(fmt)) – \(viewModel.customEnd.formatted(fmt))"
    }

    func applyPreset(_ preset: PeriodPreset) {
        let now = Date()
        let cal = Calendar.current
        let start: Date
        switch preset {
        case .week:        start = cal.date(byAdding: .day, value: -6, to: now)!
        case .month:       start = cal.date(byAdding: .day, value: -29, to: now)!
        case .threeMonths: start = cal.date(byAdding: .month, value: -3, to: now)!
        case .custom:      return
        }
        viewModel.customStart = start
        viewModel.customEnd = now
        viewModel.viewMode = .custom
    }
}

// MARK: - Period Picker Sheet

private struct PeriodPickerSheet: View {
    @Bindable var viewModel: TransactionsViewModel
    @Binding var selected: PeriodPreset
    @Environment(\.dismiss) private var dismiss

    @State private var showCustom = false

    private let presets: [PeriodPreset] = [.week, .month, .threeMonths]

    private var dayCount: Int {
        max(1, Calendar.current.dateComponents([.day], from: viewModel.customStart, to: viewModel.customEnd).day ?? 1)
    }

    var body: some View {
        VStack(spacing: 0) {

            // ── Big animated date range display ──────────────────────────
            HStack(alignment: .center, spacing: 0) {
                // Start
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.customStart, format: .dateTime.month(.abbreviated).day())
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .tracking(-1.5)
                        .contentTransition(.numericText())
                    Text(viewModel.customStart, format: .dateTime.year())
                        .font(.system(size: 11, weight: .semibold))
                        .opacity(0.35)
                }

                Spacer()

                // Day count badge in the middle
                VStack(spacing: 6) {
                    Rectangle()
                        .fill(.primary.opacity(0.12))
                        .frame(width: 1, height: 14)
                    Text("\(dayCount)d")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(.regularMaterial, in: Capsule())
                    Rectangle()
                        .fill(.primary.opacity(0.12))
                        .frame(width: 1, height: 14)
                }

                Spacer()

                // End
                VStack(alignment: .trailing, spacing: 2) {
                    Text(viewModel.customEnd, format: .dateTime.month(.abbreviated).day())
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .tracking(-1.5)
                        .contentTransition(.numericText())
                    Text(viewModel.customEnd, format: .dateTime.year())
                        .font(.system(size: 11, weight: .semibold))
                        .opacity(0.35)
                }
            }
            .padding(.horizontal, 26)
            .padding(.top, 28)
            .padding(.bottom, 22)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: dayCount)

            // Thin rule
            Rectangle()
                .fill(.primary.opacity(0.08))
                .frame(height: 1)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

            // ── Preset tiles ─────────────────────────────────────────────
            HStack(spacing: 8) {
                ForEach(presets, id: \.rawValue) { preset in
                    presetTile(preset)
                }
            }
            .padding(.horizontal, 20)

            // ── Custom row ───────────────────────────────────────────────
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    selected = .custom
                    showCustom.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Custom Range")
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(-0.2)
                    Spacer()
                    Image(systemName: showCustom ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .opacity(0.35)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(showCustom ? Color.kPrimary.opacity(0.5) : .clear, lineWidth: 1.5)
                )
            }
            .buttonStyle(KPressButtonStyle())
            .padding(.horizontal, 20)
            .padding(.top, 8)

            if showCustom {
                HStack(spacing: 14) {
                    dateField(label: "FROM", date: $viewModel.customStart)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 9, weight: .semibold))
                        .opacity(0.3)
                    dateField(label: "TO", date: $viewModel.customEnd)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .onChange(of: viewModel.customStart) { _, _ in viewModel.onCustomDateChange() }
                .onChange(of: viewModel.customEnd) { _, _ in viewModel.onCustomDateChange() }
            }

            Spacer()
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: showCustom)
    }

    @ViewBuilder
    private func presetTile(_ preset: PeriodPreset) -> some View {
        let isActive = selected == preset && !showCustom
        Button {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                selected = preset
                showCustom = false
                applyPreset(preset)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { dismiss() }
        } label: {
            VStack(spacing: 3) {
                Text(preset.buttonLabel)
                    .font(.system(size: 14, weight: .bold))
                    .tracking(-0.3)
                Text(preset.description)
                    .font(.system(size: 10, weight: .medium))
                    .opacity(0.6)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .background(isActive ? Color.kPrimary : .clear, in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(isActive ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.primary))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isActive ? .clear : Color.primary.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(KPressButtonStyle())
    }

    private func dateField(label: String, date: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            KLabel(label)
            DatePicker("", selection: date, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
        }
    }

    private func applyPreset(_ preset: PeriodPreset) {
        let now = Date()
        let cal = Calendar.current
        let start: Date
        switch preset {
        case .week:        start = cal.date(byAdding: .day, value: -6, to: now)!
        case .month:       start = cal.date(byAdding: .day, value: -29, to: now)!
        case .threeMonths: start = cal.date(byAdding: .month, value: -3, to: now)!
        case .custom:      return
        }
        viewModel.customStart = start
        viewModel.customEnd = now
        viewModel.viewMode = .custom
    }
}

// MARK: - Period Preset

enum PeriodPreset: String, CaseIterable {
    case week        = "Week"
    case month       = "Month"
    case threeMonths = "3 Months"
    case custom      = "Custom"

    var buttonLabel: String {
        switch self {
        case .week:        return "Week"
        case .month:       return "Month"
        case .threeMonths: return "3M"
        case .custom:      return "Custom"
        }
    }

    var description: String {
        switch self {
        case .week:        return "Last 7 days"
        case .month:       return "Last 30 days"
        case .threeMonths: return "Last 3 months"
        case .custom:      return "Any range"
        }
    }
}

// MARK: - Summary Strip

struct TransactionsSummaryStrip: View {
    @Bindable var viewModel: TransactionsViewModel

    var body: some View {
        let net = viewModel.totalIncome - viewModel.totalSpent

        HStack(spacing: 0) {
            metric(label: "SPENT", value: formatCurrency(viewModel.totalSpent))
            KDivider(height: 24)
            metric(label: "IN", value: formatCurrency(viewModel.totalIncome), color: Color.kGreen)
            KDivider(height: 24)
            metric(
                label: "NET",
                value: "\(net >= 0 ? "+" : "")\(formatCurrency(net))",
                color: net >= 0 ? Color.kGreen : Color.kRed
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.kDividerBg)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.kBorder).frame(height: 1)
        }
    }

    private func metric(label: String, value: String, color: Color = Color.kPrimary) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .tracking(-0.4)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())
            KLabel(label)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatCurrency(_ value: Double) -> String {
        abs(value).formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }
}

// MARK: - Transaction Tab

enum TransactionTab: String, CaseIterable, Identifiable {
    case analytics, ledger, merchants, search

    var id: String { rawValue }

    var label: String {
        switch self {
        case .analytics: "Analytics"
        case .ledger: "Ledger"
        case .merchants: "Merchants"
        case .search: "Search"
        }
    }

    var icon: String {
        switch self {
        case .analytics: "chart.pie"
        case .ledger: "list.bullet.rectangle"
        case .merchants: "storefront"
        case .search: "magnifyingglass"
        }
    }
}

// MARK: - View Mode

enum ViewMode: String, CaseIterable, Identifiable {
    case weekly, biweekly, monthly, custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .weekly: "Weekly"
        case .biweekly: "Biweekly"
        case .monthly: "Monthly"
        case .custom: "Custom"
        }
    }
}

// MARK: - Time Range (kept for Search tab)

enum TimeRange: String, CaseIterable, Identifiable {
    case sevenDays = "7d"
    case thirtyDays = "30d"
    case ninetyDays = "90d"
    case sixMonths = "6m"
    case oneYear = "1y"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sevenDays: "7 Days"
        case .thirtyDays: "30 Days"
        case .ninetyDays: "90 Days"
        case .sixMonths: "6 Months"
        case .oneYear: "1 Year"
        }
    }

    var dateRange: (start: Date, end: Date) {
        let end = Date()
        let start: Date
        switch self {
        case .sevenDays: start = Calendar.current.date(byAdding: .day, value: -7, to: end)!
        case .thirtyDays: start = Calendar.current.date(byAdding: .day, value: -30, to: end)!
        case .ninetyDays: start = Calendar.current.date(byAdding: .day, value: -90, to: end)!
        case .sixMonths: start = Calendar.current.date(byAdding: .month, value: -6, to: end)!
        case .oneYear: start = Calendar.current.date(byAdding: .year, value: -1, to: end)!
        }
        return (start, end)
    }
}

// MARK: - Day Group (Ledger)

struct DayGroup: Identifiable {
    let id: String
    let date: String
    let label: String
    let dayOfWeek: String
    let txnCount: Int
    let pendingCount: Int
    let dayDebit: Double
    let dayCredit: Double
    var transactions: [TransactionDTO] = []
    var loaded: Bool = false
    var loading: Bool = false
}

// MARK: - Merchant Summary

struct MerchantSummary: Identifiable {
    let id = UUID()
    let name: String
    var totalSpent: Double = 0
    var totalEarned: Double = 0
    var transactionCount: Int = 0
    var lastTransactionDate: Date = .distantPast
    var firstTransactionDate: Date = .distantFuture
    var categories: Set<String> = []
    var sharePercent: Double = 0

    var totalVolume: Double { totalSpent + totalEarned }

    var averageTransaction: Double {
        guard transactionCount > 0 else { return 0 }
        return totalVolume / Double(transactionCount)
    }

    var isRecurring: Bool { transactionCount >= 3 }
}

// MARK: - Merchant Detail

struct MerchantDetail {
    let totalSpent: Double
    let totalEarned: Double
    let netAmount: Double
    let firstSeen: String
    let lastSeen: String
    let transactions: [TransactionDTO]
}

// MARK: - Sort Field

enum MerchantSortField: String, CaseIterable {
    case name, totalVolume, transactionCount, averageTransaction

    var label: String {
        switch self {
        case .name: "Name"
        case .totalVolume: "Volume"
        case .transactionCount: "Transactions"
        case .averageTransaction: "Average"
        }
    }
}

// MARK: - Search Filters

struct SearchFilters {
    var searchText = ""
    var transactionType = "all"
    var category = "all"
    var minAmount: Double?
    var maxAmount: Double?
    var startDate: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
    var endDate: Date = Date()
    var merchantName = ""
}

struct SavedFilter: Identifiable, Codable {
    let id: String
    let name: String
    let searchText: String
    let transactionType: String
    let category: String
    let minAmount: Double?
    let maxAmount: Double?
    let startDateStr: String
    let endDateStr: String
    let merchantName: String
    let createdAt: Date
}

// MARK: - Transactions View Model

@Observable
@MainActor
final class TransactionsViewModel {
    // Period picker
    var viewMode: ViewMode = .weekly
    var periodOffset: Int = 0
    var customStart: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
    var customEnd: Date = Date()

    var isLoading = false
    var errorMessage: String?

    // Summary stats
    var totalSpent: Double = 0
    var totalIncome: Double = 0
    var expenseCount: Int = 0
    var incomeCount: Int = 0
    var totalCount: Int = 0
    var hasTransactions = false

    // Analytics data
    var analysisData: SpendingAnalysisResponseDTO?

    // Ledger data
    var ledgerDayGroups: [DayGroup] = []
    var expandedDays: Set<String> = []
    var expandedTransactionId: Int?
    var ledgerTotalDebits: Double = 0
    var ledgerTotalCredits: Double = 0
    var ledgerNetFlow: Double = 0
    var ledgerTxnCount: Int = 0

    // Legacy ledger (compatibility)
    var transactions: [TransactionDTO] = []
    var currentPage = 1
    var totalPages = 1

    // Merchants data
    var merchantSummaries: [MerchantSummary] = []
    var merchantSortField: MerchantSortField = .totalVolume
    var merchantSortAscending = false
    var expandedMerchantName: String?
    var merchantDetails: [String: MerchantDetail] = [:]
    var merchantDetailLoading: Set<String> = []
    var merchantTotalVolume: Double = 0
    var merchantRecurringCount: Int = 0
    var merchantAvgPerMerchant: Double = 0

    // Search data
    var searchFilters = SearchFilters()
    var searchResults: [TransactionDTO] = []
    var searchPage = 1
    var searchTotalPages = 1
    var searchTotalCount = 0
    var isSearchLoading = false
    var savedFilters: [SavedFilter] = []
    var categories: [String] = []

    let api = TransactionsAPI(client: AppAPIClient.live())
    private let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()

    // MARK: - Period Computed Properties

    var periodStartDate: String {
        viewMode == .custom
            ? dateFormatter.string(from: customStart)
            : dateFormatter.string(from: computePeriodBounds().start)
    }

    var periodEndDate: String {
        if viewMode == .custom { return dateFormatter.string(from: customEnd) }
        let bounds = computePeriodBounds()
        let now = Date()
        return dateFormatter.string(from: bounds.end > now ? now : bounds.end)
    }

    var periodLabel: String {
        if viewMode == .custom {
            let fmt = Date.FormatStyle().month(.abbreviated).day()
            return "\(customStart.formatted(fmt)) – \(customEnd.formatted(fmt))"
        }
        let bounds = computePeriodBounds()
        if viewMode == .monthly {
            return bounds.start.formatted(.dateTime.month(.wide).year())
        }
        let fmt = Date.FormatStyle().month(.abbreviated).day()
        return "\(bounds.start.formatted(fmt)) – \(bounds.end.formatted(fmt)), \(bounds.end.formatted(.dateTime.year()))"
    }

    var periodShortLabel: String {
        if viewMode == .custom { return "Custom Range" }
        if periodOffset == 0 {
            switch viewMode {
            case .weekly: return "This Week"
            case .biweekly: return "This Fortnight"
            case .monthly: return "This Month"
            case .custom: return ""
            }
        }
        if periodOffset == -1 {
            switch viewMode {
            case .weekly: return "Last Week"
            case .biweekly: return "Last Fortnight"
            case .monthly: return "Last Month"
            case .custom: return ""
            }
        }
        return ""
    }

    var isCurrentPeriod: Bool { viewMode == .custom || periodOffset == 0 }

    var netCashFlow: Double { totalIncome - totalSpent }

    // MARK: - Period Navigation

    func prevPeriod() { periodOffset -= 1 }

    func nextPeriod() {
        if periodOffset < 0 { periodOffset += 1 }
    }

    func goToday() {
        guard periodOffset != 0 else { return }
        periodOffset = 0
    }

    func initCustomDates() {
        let now = Date()
        customStart = Calendar.current.date(byAdding: .day, value: -30, to: now)!
        customEnd = now
    }

    func onCustomDateChange() {
        guard customStart <= customEnd else { return }
        let diffDays = Calendar.current.dateComponents([.day], from: customStart, to: customEnd).day ?? 0
        if diffDays > 90 {
            customStart = Calendar.current.date(byAdding: .day, value: -90, to: customEnd)!
        }
    }

    private func computePeriodBounds() -> (start: Date, end: Date) {
        let today = Date()
        let cal = Calendar.current

        switch viewMode {
        case .weekly:
            let dow = cal.component(.weekday, from: today) - 1
            var start = cal.date(byAdding: .day, value: -dow + periodOffset * 7, to: today)!
            start = cal.startOfDay(for: start)
            let end = cal.date(byAdding: .day, value: 6, to: start)!
            return (start, end)

        case .biweekly:
            let dow = cal.component(.weekday, from: today) - 1
            var start = cal.date(byAdding: .day, value: -dow + periodOffset * 14, to: today)!
            start = cal.startOfDay(for: start)
            let end = cal.date(byAdding: .day, value: 13, to: start)!
            return (start, end)

        case .monthly:
            var comps = cal.dateComponents([.year, .month], from: today)
            comps.month! += periodOffset
            let start = cal.date(from: comps)!
            comps.month! += 1
            comps.day = 0
            let end = cal.date(from: comps)!
            return (start, end)

        case .custom:
            return (customStart, customEnd)
        }
    }

    // MARK: - Data Loading

    func loadInitialData(userId: String) async {
        guard !userId.isEmpty else { return }
        isLoading = true
        await loadSummary(userId: userId)
        await loadAnalytics(userId: userId)
        isLoading = false
    }

    func refresh(userId: String) async {
        await loadInitialData(userId: userId)
    }

    func loadSummary(userId: String) async {
        do {
            let response = try await api.getAllTransactions(
                userId: userId, page: 1, pageSize: 1,
                startDate: periodStartDate, endDate: periodEndDate
            )
            totalCount = response.totalCount ?? 0
            totalSpent = response.totalSpent ?? 0
            totalIncome = response.totalIncome ?? 0
            expenseCount = response.expenseCount ?? 0
            incomeCount = response.incomeCount ?? 0
            hasTransactions = totalCount > 0
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadAnalytics(userId: String) async {
        guard !userId.isEmpty else { return }
        do {
            analysisData = try await api.getSpendingAnalysis(
                userId: userId, startDate: periodStartDate, endDate: periodEndDate
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Ledger

    func loadLedgerSummary(userId: String) async {
        guard !userId.isEmpty else { return }
        isLoading = true
        expandedDays.removeAll()
        expandedTransactionId = nil

        do {
            let analysis = try await api.getSpendingAnalysis(
                userId: userId, startDate: periodStartDate, endDate: periodEndDate
            )

            ledgerTotalDebits = analysis.totalSpent ?? 0
            ledgerTotalCredits = analysis.totalIncome ?? 0
            ledgerNetFlow = ledgerTotalCredits - ledgerTotalDebits
            ledgerTxnCount = analysis.totalTransactions ?? 0

            totalSpent = analysis.totalSpent ?? 0
            totalIncome = analysis.totalIncome ?? 0

            let daily = (analysis.dailyBreakdown ?? [])
                .filter { ($0.transactionCount ?? 0) > 0 }
                .sorted { parseDate($0.date) > parseDate($1.date) }

            ledgerDayGroups = daily.map { d in
                let dt = parseDate(d.date)
                let dateKey = String(d.date.prefix(10))
                return DayGroup(
                    id: dateKey,
                    date: dateKey,
                    label: dt.formatted(.dateTime.month(.abbreviated).day().year()),
                    dayOfWeek: dt.formatted(.dateTime.weekday(.wide)),
                    txnCount: d.transactionCount ?? 0,
                    pendingCount: 0,
                    dayDebit: d.spending,
                    dayCredit: d.income ?? 0
                )
            }
        } catch {
            ledgerDayGroups = []
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func toggleDay(_ date: String, userId: String) async {
        if expandedDays.contains(date) {
            expandedDays.remove(date)
            return
        }
        expandedDays.insert(date)

        guard let idx = ledgerDayGroups.firstIndex(where: { $0.date == date }),
              !ledgerDayGroups[idx].loaded else { return }

        ledgerDayGroups[idx].loading = true
        do {
            let resp = try await api.getAllTransactions(
                userId: userId, page: 1, pageSize: 200,
                startDate: date, endDate: date, sortBy: "date", sortOrder: "desc"
            )
            ledgerDayGroups[idx].transactions = resp.transactions ?? []
            ledgerDayGroups[idx].loaded = true
        } catch {
            ledgerDayGroups[idx].transactions = []
            ledgerDayGroups[idx].loaded = true
        }
        ledgerDayGroups[idx].loading = false
    }

    // MARK: - Merchants

    func loadMerchants(userId: String) async {
        guard !userId.isEmpty else { return }
        isLoading = true
        expandedMerchantName = nil
        merchantDetails.removeAll()

        let startDate = periodStartDate
        let endDate = periodEndDate

        do {
            var allTransactions: [TransactionDTO] = []
            var page = 1
            var hasMore = true

            while hasMore && page <= 10 {
                let response = try await api.getAllTransactions(
                    userId: userId, page: page, pageSize: 100,
                    startDate: startDate, endDate: endDate
                )
                allTransactions.append(contentsOf: response.transactions ?? [])
                hasMore = response.pagination?.hasNext ?? false
                page += 1
            }

            var merchantMap: [String: MerchantSummary] = [:]
            for tx in allTransactions {
                let name = tx.merchantName ?? tx.name ?? "Unknown"
                var summary = merchantMap[name] ?? MerchantSummary(name: name)

                if tx.isExpense { summary.totalSpent += tx.displayAmount }
                else { summary.totalEarned += tx.displayAmount }
                summary.transactionCount += 1

                if let cat = tx.category { summary.categories.insert(cat) }

                let txDate = parseDate(tx.date)
                if txDate > summary.lastTransactionDate { summary.lastTransactionDate = txDate }
                if txDate < summary.firstTransactionDate { summary.firstTransactionDate = txDate }

                merchantMap[name] = summary
            }

            let grandTotal = merchantMap.values.reduce(0.0) { $0 + $1.totalVolume }

            merchantSummaries = merchantMap.values.map { m in
                var copy = m
                copy.sharePercent = grandTotal > 0 ? (m.totalVolume / grandTotal) * 100 : 0
                return copy
            }

            applyMerchantSort()
            merchantTotalVolume = grandTotal
            merchantRecurringCount = merchantSummaries.filter(\.isRecurring).count
            merchantAvgPerMerchant = merchantSummaries.isEmpty ? 0 : grandTotal / Double(merchantSummaries.count)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func toggleMerchantSort(_ field: MerchantSortField) {
        if merchantSortField == field {
            merchantSortAscending.toggle()
        } else {
            merchantSortField = field
            merchantSortAscending = field == .name
        }
        applyMerchantSort()
    }

    func applyMerchantSort() {
        let asc = merchantSortAscending
        merchantSummaries.sort { a, b in
            let result: Bool
            switch merchantSortField {
            case .name: result = a.name.localizedCompare(b.name) == .orderedAscending
            case .totalVolume: result = a.totalVolume < b.totalVolume
            case .transactionCount: result = a.transactionCount < b.transactionCount
            case .averageTransaction: result = a.averageTransaction < b.averageTransaction
            }
            return asc ? result : !result
        }
    }

    func toggleMerchantExpand(_ name: String, userId: String) async {
        if expandedMerchantName == name {
            expandedMerchantName = nil
            return
        }
        expandedMerchantName = name

        guard merchantDetails[name] == nil else { return }
        merchantDetailLoading.insert(name)

        do {
            var results: [TransactionDTO] = []
            var page = 1
            var hasMore = true

            while hasMore && page <= 20 {
                let resp = try await api.getAllTransactions(
                    userId: userId, page: page, pageSize: 100,
                    startDate: periodStartDate, endDate: periodEndDate
                )
                for t in (resp.transactions ?? []) {
                    let txName = t.merchantName ?? t.name ?? "Unknown"
                    if txName == name { results.append(t) }
                }
                hasMore = resp.pagination?.hasNext ?? false
                page += 1
            }

            results.sort { parseDate($0.date) > parseDate($1.date) }

            var spent = 0.0, earned = 0.0
            var firstDate: Date?
            var lastDate: Date?

            for t in results {
                if t.amount > 0 { spent += t.amount } else { earned += abs(t.amount) }
                let d = parseDate(t.date)
                if firstDate == nil || d < firstDate! { firstDate = d }
                if lastDate == nil || d > lastDate! { lastDate = d }
            }

            merchantDetails[name] = MerchantDetail(
                totalSpent: spent,
                totalEarned: earned,
                netAmount: spent - earned,
                firstSeen: firstDate.map { dateFormatter.string(from: $0) } ?? periodStartDate,
                lastSeen: lastDate.map { dateFormatter.string(from: $0) } ?? periodEndDate,
                transactions: results
            )
        } catch {
            merchantDetails[name] = MerchantDetail(
                totalSpent: 0, totalEarned: 0, netAmount: 0,
                firstSeen: periodStartDate, lastSeen: periodEndDate, transactions: []
            )
        }
        merchantDetailLoading.remove(name)
    }

    // MARK: - Search

    func executeSearch(userId: String) async {
        guard !userId.isEmpty else { return }
        isSearchLoading = true

        let startDate = dateFormatter.string(from: searchFilters.startDate)
        let endDate = dateFormatter.string(from: searchFilters.endDate)
        let search = searchFilters.searchText.isEmpty ? nil : searchFilters.searchText

        do {
            let response = try await api.getAllTransactions(
                userId: userId, page: searchPage, pageSize: 20,
                startDate: startDate, endDate: endDate,
                search: search, sortBy: "date", sortOrder: "desc"
            )

            var txns = response.transactions ?? []

            txns = txns.filter { t in
                if searchFilters.transactionType == "expense" && !t.isExpense { return false }
                if searchFilters.transactionType == "income" && !t.isIncome { return false }
                if let min = searchFilters.minAmount, t.displayAmount < min { return false }
                if let max = searchFilters.maxAmount, t.displayAmount > max { return false }
                if searchFilters.category != "all" && t.category != searchFilters.category { return false }
                if !searchFilters.merchantName.isEmpty {
                    guard (t.merchantName ?? "").lowercased().contains(searchFilters.merchantName.lowercased()) else { return false }
                }
                return true
            }

            searchResults = txns
            searchTotalCount = response.pagination?.totalItems ?? txns.count
            searchTotalPages = response.pagination?.totalPages ?? 1
        } catch {
            searchResults = []
            errorMessage = error.localizedDescription
        }
        isSearchLoading = false
    }

    func loadCategories(userId: String) async {
        guard !userId.isEmpty else { return }
        do {
            let response = try await api.getAllTransactions(userId: userId, page: 1, pageSize: 100)
            let catSet = Set((response.transactions ?? []).compactMap(\.category))
            categories = catSet.sorted()
        } catch { }
    }

    func clearSearchFilters() {
        searchFilters = SearchFilters()
        searchResults = []
        searchPage = 1
    }

    func saveFilter(name: String) {
        let filter = SavedFilter(
            id: UUID().uuidString, name: name,
            searchText: searchFilters.searchText,
            transactionType: searchFilters.transactionType,
            category: searchFilters.category,
            minAmount: searchFilters.minAmount,
            maxAmount: searchFilters.maxAmount,
            startDateStr: dateFormatter.string(from: searchFilters.startDate),
            endDateStr: dateFormatter.string(from: searchFilters.endDate),
            merchantName: searchFilters.merchantName,
            createdAt: Date()
        )
        savedFilters.append(filter)
        persistSavedFilters()
    }

    func loadSavedFilter(_ filter: SavedFilter) {
        searchFilters.searchText = filter.searchText
        searchFilters.transactionType = filter.transactionType
        searchFilters.category = filter.category
        searchFilters.minAmount = filter.minAmount
        searchFilters.maxAmount = filter.maxAmount
        searchFilters.merchantName = filter.merchantName
        if let d = dateFormatter.date(from: filter.startDateStr) { searchFilters.startDate = d }
        if let d = dateFormatter.date(from: filter.endDateStr) { searchFilters.endDate = d }
    }

    func deleteSavedFilter(id: String) {
        savedFilters.removeAll { $0.id == id }
        persistSavedFilters()
    }

    func loadPersistedFilters() {
        guard let data = UserDefaults.standard.data(forKey: "savedTransactionFilters"),
              let filters = try? JSONDecoder().decode([SavedFilter].self, from: data) else { return }
        savedFilters = filters
    }

    private func persistSavedFilters() {
        if let data = try? JSONEncoder().encode(savedFilters) {
            UserDefaults.standard.set(data, forKey: "savedTransactionFilters")
        }
    }

    // MARK: - Helpers

    func parseDate(_ dateString: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) { return date }
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: dateString) ?? .distantPast
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TransactionsView(viewModel: TransactionsViewModel(), tab: .analytics)
    }
    .environment(\.injected, .previewAuthenticated)
}
