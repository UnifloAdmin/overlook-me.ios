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
            }
        }
        .navigationTitle(tab.label)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                timeRangeMenu
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                refreshButton
            }
        }
        .task {
            await loadDataForTab()
        }
        .onChange(of: viewModel.selectedTimeRange) { _, _ in
            reloadForTab()
        }
        .tabBarConfig(.transactions)
    }
    
    private var timeRangeMenu: some View {
        Menu {
            ForEach(TimeRange.allCases) { range in
                Button {
                    viewModel.selectedTimeRange = range
                } label: {
                    if viewModel.selectedTimeRange == range {
                        Label(range.label, systemImage: "checkmark")
                    } else {
                        Text(range.label)
                    }
                }
            }
        } label: {
            Label(viewModel.selectedTimeRange.label, systemImage: "calendar")
        }
    }
    
    private var refreshButton: some View {
        Button(action: { performRefresh() }) {
            if viewModel.isLoading {
                ProgressView()
            } else {
                Image(systemName: "arrow.clockwise")
            }
        }
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
            if viewModel.transactions.isEmpty {
                await viewModel.loadTransactions(userId: userId)
            }
        case .merchants:
            if viewModel.merchantSummaries.isEmpty {
                await viewModel.loadMerchants(userId: userId)
            }
        }
    }
    
    private func reloadForTab() {
        let uid = userId
        let vm = viewModel
        let currentTab = tab
        _Concurrency.Task {
            switch currentTab {
            case .analytics:
                await vm.loadAnalytics(userId: uid)
            case .ledger:
                await vm.loadTransactions(userId: uid)
            case .merchants:
                await vm.loadMerchants(userId: uid)
            }
        }
    }
}

// MARK: - Transaction Tab

enum TransactionTab: String, CaseIterable, Identifiable {
    case analytics, ledger, merchants
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .analytics: "Analytics"
        case .ledger: "Ledger"
        case .merchants: "Merchants"
        }
    }
    
    var icon: String {
        switch self {
        case .analytics: "chart.pie"
        case .ledger: "list.bullet.rectangle"
        case .merchants: "storefront"
        }
    }
}

// MARK: - Time Range

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

// MARK: - Transactions View Model

@Observable
@MainActor
final class TransactionsViewModel {
    var selectedTimeRange: TimeRange = .ninetyDays
    var isLoading = false
    var errorMessage: String?
    
    // Summary stats
    var totalSpent: Double = 0
    var totalIncome: Double = 0
    var expenseCount: Int = 0
    var incomeCount: Int = 0
    var hasTransactions = false
    
    // Analytics data
    var analysisData: SpendingAnalysisResponseDTO?
    
    // Ledger data
    var transactions: [TransactionDTO] = []
    var currentPage = 1
    var totalPages = 1
    var totalCount = 0
    
    // Merchants data
    var merchantSummaries: [MerchantSummary] = []
    
    private let api = TransactionsAPI(client: AppAPIClient.live())
    private let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()
    
    var spendingToIncomeRatio: Double? {
        guard totalIncome > 0 else { return nil }
        return totalSpent / totalIncome
    }
    
    var netCashFlow: Double {
        totalIncome - totalSpent
    }
    
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
            let response = try await api.getAllTransactions(userId: userId, page: 1, pageSize: 1)
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
        let range = selectedTimeRange.dateRange
        let startDate = dateFormatter.string(from: range.start)
        let endDate = dateFormatter.string(from: range.end)
        
        do {
            analysisData = try await api.getSpendingAnalysis(userId: userId, startDate: startDate, endDate: endDate)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func loadTransactions(userId: String, page: Int = 1) async {
        guard !userId.isEmpty else { return }
        isLoading = true
        currentPage = page
        
        let range = selectedTimeRange.dateRange
        let startDate = dateFormatter.string(from: range.start)
        let endDate = dateFormatter.string(from: range.end)
        
        do {
            let response = try await api.getAllTransactions(
                userId: userId,
                page: page,
                pageSize: 20,
                startDate: startDate,
                endDate: endDate
            )
            transactions = response.transactions ?? []
            totalPages = response.pagination?.totalPages ?? 1
            totalCount = response.totalCount ?? 0
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func loadMerchants(userId: String) async {
        guard !userId.isEmpty else { return }
        isLoading = true
        
        let range = selectedTimeRange.dateRange
        let startDate = dateFormatter.string(from: range.start)
        let endDate = dateFormatter.string(from: range.end)
        
        do {
            // Fetch all transactions to aggregate merchants
            var allTransactions: [TransactionDTO] = []
            var page = 1
            var hasMore = true
            
            while hasMore && page <= 10 {
                let response = try await api.getAllTransactions(
                    userId: userId,
                    page: page,
                    pageSize: 100,
                    startDate: startDate,
                    endDate: endDate
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
                
                let txDate = parseDate(tx.date)
                if txDate > summary.lastTransactionDate {
                    summary.lastTransactionDate = txDate
                }
                
                merchantMap[name] = summary
            }
            
            merchantSummaries = merchantMap.values
                .sorted { ($0.totalSpent + $0.totalEarned) > ($1.totalSpent + $1.totalEarned) }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    private func parseDate(_ dateString: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) { return date }
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: dateString) ?? .distantPast
    }
}

// MARK: - Merchant Summary

struct MerchantSummary: Identifiable {
    let id = UUID()
    let name: String
    var totalSpent: Double = 0
    var totalEarned: Double = 0
    var transactionCount: Int = 0
    var lastTransactionDate: Date = .distantPast
    
    var averageTransaction: Double {
        guard transactionCount > 0 else { return 0 }
        return (totalSpent + totalEarned) / Double(transactionCount)
    }
    
    var isRecurring: Bool { transactionCount >= 3 }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TransactionsView(viewModel: TransactionsViewModel(), tab: .analytics)
    }
    .environment(\.injected, .previewAuthenticated)
}
