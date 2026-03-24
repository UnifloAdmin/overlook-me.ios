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
        .background(Color.kSurface)
        .navigationTitle(tab.label)
        .toolbarTitleDisplayMode(.inline)
        .task {
            await loadDataForTab()
        }
        .onChange(of: viewModel.viewMode) { _, _ in
            reloadForCurrentTab()
        }
        .onChange(of: viewModel.periodOffset) { _, _ in
            reloadForCurrentTab()
        }
        .tabBarConfig(.transactions)
    }
    
    // MARK: - Period Picker
    
    // MARK: - Toolbar: Refresh (Kalshi spec: 28×28, border-radius 999, icon 14px)
    
    private var refreshButton: some View {
        Button(action: { performRefresh() }) {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14))
                }
            }
            .foregroundStyle(Color.kSecondary)
            .frame(width: 28, height: 28)
            .background(Color.kSurface, in: Circle())
            .overlay(Circle().stroke(Color.kBorderMedium, lineWidth: 1))
        }
        .buttonStyle(KPressButtonStyle())
        .disabled(viewModel.isLoading)
    }
    
    private func performRefresh() {
        let uid = userId
        let vm = viewModel
        _Concurrency.Task {
            await vm.refresh(userId: uid)
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
            case .analytics:
                await vm.loadAnalytics(userId: uid)
            case .ledger:
                await vm.loadLedgerSummary(userId: uid)
            case .merchants:
                await vm.loadMerchants(userId: uid)
            case .search:
                break
            }
        }
    }
    
    private func formatCurrency(_ value: Double) -> String {
        value.formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }
}

// MARK: - Period Picker (standalone — embed in each sub-view's ScrollView)

struct TransactionsPeriodPicker: View {
    @Bindable var viewModel: TransactionsViewModel
    
    var body: some View {
        VStack(spacing: 10) {
            // Native iOS segmented picker — not edge-to-edge
            Picker("Period", selection: Binding(
                get: { viewModel.viewMode },
                set: { newMode in
                    withAnimation(.easeInOut(duration: 0.12)) {
                        viewModel.viewMode = newMode
                        viewModel.periodOffset = 0
                        if newMode == .custom {
                            viewModel.initCustomDates()
                        }
                    }
                }
            )) {
                ForEach(ViewMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .disabled(viewModel.isLoading)
            
            if viewModel.viewMode != .custom {
                periodNavigationRow
            } else {
                customDatePickerRow
            }
        }
    }
    
    private var periodNavigationRow: some View {
        VStack(spacing: 6) {
            HStack(spacing: 16) {
                Spacer()
                
                Button { viewModel.prevPeriod() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.kSecondary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                }
                .disabled(viewModel.isLoading)
                
                VStack(spacing: 2) {
                    Text(viewModel.periodLabel)
                        .font(.system(size: 16, weight: .bold))
                        .tracking(-0.32)
                        .foregroundStyle(Color.kPrimary)
                    
                    if !viewModel.periodShortLabel.isEmpty {
                        Text(viewModel.periodShortLabel)
                            .font(.system(size: 11, weight: .medium))
                            .tracking(0.2)
                            .foregroundStyle(Color.kTertiary)
                    }
                }
                
                Button { viewModel.nextPeriod() } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(viewModel.isCurrentPeriod ? Color.kPlaceholder : Color.kSecondary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                }
                .buttonStyle(KPressButtonStyle())
                .disabled(viewModel.isLoading || viewModel.isCurrentPeriod)
                
                Spacer()
            }
            
            if !viewModel.isCurrentPeriod {
                Button {
                    viewModel.goToday()
                } label: {
                    Text("TODAY")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(Color.kBlue)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 6)
                        .background(Color.kBlueBg, in: Capsule())
                }
                .buttonStyle(KPressButtonStyle())
            }
        }
    }
    
    private var customDatePickerRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("FROM")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(Color.kTertiary)
                DatePicker("", selection: $viewModel.customStart, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
            }
            
            Text("–")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.kTertiary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("TO")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(Color.kTertiary)
                DatePicker("", selection: $viewModel.customEnd, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
            }
            
            Spacer()
        }
        .onChange(of: viewModel.customStart) { _, _ in viewModel.onCustomDateChange() }
        .onChange(of: viewModel.customEnd) { _, _ in viewModel.onCustomDateChange() }
    }
}

// MARK: - Summary Strip (Kalshi Hero Style)

struct TransactionsSummaryStrip: View {
    @Bindable var viewModel: TransactionsViewModel
    
    var body: some View {
        let net = viewModel.totalIncome - viewModel.totalSpent
        
        HStack(spacing: 0) {
            heroMetric(label: "Spent", value: formatCurrency(viewModel.totalSpent))
            
            Rectangle()
                .fill(Color.kBorderMedium)
                .frame(width: 1, height: 32)
            
            heroMetric(label: "Income", value: formatCurrency(viewModel.totalIncome))
            
            Rectangle()
                .fill(Color.kBorderMedium)
                .frame(width: 1, height: 32)
            
            heroMetric(label: "Net", value: "\(net >= 0 ? "+" : "")\(formatCurrency(net))")
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 4)
    }
    
    private func heroMetric(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 23, weight: .bold)) // Kalshi Large Metric
                .tracking(-0.92)
                .foregroundStyle(Color.kPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
            
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(Color.kTertiary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func formatCurrency(_ value: Double) -> String {
        value.formatted(.currency(code: "USD").precision(.fractionLength(0)))
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
    let id: String  // date string
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
    var transactionType = "all"  // all, expense, income
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
    
    // Legacy ledger (keep for compatibility during transition)
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
        if viewMode == .custom {
            return dateFormatter.string(from: customStart)
        }
        let bounds = computePeriodBounds()
        return dateFormatter.string(from: bounds.start)
    }
    
    var periodEndDate: String {
        if viewMode == .custom {
            return dateFormatter.string(from: customEnd)
        }
        let bounds = computePeriodBounds()
        let now = Date()
        let cappedEnd = bounds.end > now ? now : bounds.end
        return dateFormatter.string(from: cappedEnd)
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
    
    var isCurrentPeriod: Bool {
        viewMode == .custom || periodOffset == 0
    }
    
    var spendingToIncomeRatio: Double? {
        guard totalIncome > 0 else { return nil }
        return totalSpent / totalIncome
    }
    
    var netCashFlow: Double {
        totalIncome - totalSpent
    }
    
    // MARK: - Period Navigation
    
    func prevPeriod() {
        periodOffset -= 1
    }
    
    func nextPeriod() {
        if periodOffset < 0 {
            periodOffset += 1
        }
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
        // Enforce 90-day max
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
            let dow = cal.component(.weekday, from: today) - 1 // 0 = Sun
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
            comps.day = 0 // last day of previous month
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
        let startDate = periodStartDate
        let endDate = periodEndDate
        
        do {
            analysisData = try await api.getSpendingAnalysis(userId: userId, startDate: startDate, endDate: endDate)
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
            let analysis = try await api.getSpendingAnalysis(userId: userId, startDate: periodStartDate, endDate: periodEndDate)
            
            ledgerTotalDebits = analysis.totalSpent ?? 0
            ledgerTotalCredits = analysis.totalIncome ?? 0
            ledgerNetFlow = ledgerTotalCredits - ledgerTotalDebits
            ledgerTxnCount = analysis.totalTransactions ?? 0
            
            // Also update shared stats
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
                startDate: date, endDate: date,
                sortBy: "date", sortOrder: "desc"
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
            // Fetch all transactions to aggregate merchants
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
            
            // Aggregate by merchant
            var merchantMap: [String: MerchantSummary] = [:]
            for tx in allTransactions {
                let name = tx.merchantName ?? tx.name ?? "Unknown"
                var summary = merchantMap[name] ?? MerchantSummary(name: name)
                
                if tx.isExpense {
                    summary.totalSpent += tx.displayAmount
                } else {
                    summary.totalEarned += tx.displayAmount
                }
                summary.transactionCount += 1
                
                if let cat = tx.category {
                    summary.categories.insert(cat)
                }
                
                let txDate = parseDate(tx.date)
                if txDate > summary.lastTransactionDate {
                    summary.lastTransactionDate = txDate
                }
                if txDate < summary.firstTransactionDate {
                    summary.firstTransactionDate = txDate
                }
                
                merchantMap[name] = summary
            }
            
            // Calculate grand total for share %
            let grandTotal = merchantMap.values.reduce(0.0) { $0 + $1.totalVolume }
            
            merchantSummaries = merchantMap.values
                .map { var m = $0; m.sharePercent = grandTotal > 0 ? (m.totalVolume / grandTotal) * 100 : 0; return m }
            
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
            // Fetch transactions for this merchant
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
                if t.amount > 0 { spent += t.amount }
                else { earned += abs(t.amount) }
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
            
            // Apply client-side filters
            txns = txns.filter { t in
                if searchFilters.transactionType == "expense" && !t.isExpense { return false }
                if searchFilters.transactionType == "income" && !t.isIncome { return false }
                
                if let min = searchFilters.minAmount, t.displayAmount < min { return false }
                if let max = searchFilters.maxAmount, t.displayAmount > max { return false }
                
                if searchFilters.category != "all" && t.category != searchFilters.category { return false }
                
                if !searchFilters.merchantName.isEmpty {
                    let merchantLower = searchFilters.merchantName.lowercased()
                    guard (t.merchantName ?? "").lowercased().contains(merchantLower) else { return false }
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
        } catch { /* ignore */ }
    }
    
    func clearSearchFilters() {
        searchFilters = SearchFilters()
        searchResults = []
        searchPage = 1
    }
    
    func saveFilter(name: String) {
        let filter = SavedFilter(
            id: UUID().uuidString,
            name: name,
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
