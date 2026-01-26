import SwiftUI
import Combine
import Foundation

// MARK: - Bank Account Trends View

struct BankAccountTrendsView: View {
    @Environment(\.injected) private var container: DIContainer
    @StateObject private var viewModel = BankAccountTrendsViewModel()
    
    private var userId: String {
        container.appState.state.auth.user?.id ?? ""
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                periodSelector
                
                if viewModel.isLoading {
                    loadingView
                } else if let data = viewModel.trendsData?.data {
                    if let summary = data.summary {
                        summaryCards(summary)
                    }
                    
                    if !data.snapshots.isEmpty {
                        balanceChart(data.snapshots)
                    }
                    
                    if let byAccount = data.byAccount, !byAccount.isEmpty {
                        accountsSection(byAccount)
                    }
                    
                    if !data.snapshots.isEmpty {
                        dailyHistorySection(data.snapshots)
                    }
                } else {
                    emptyState
                }
            }
            .padding(.bottom, 100)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Trends")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: refreshBalances) {
                    if viewModel.isRefreshing {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(viewModel.isRefreshing)
            }
        }
        .onAppear {
            loadTrendsIfNeeded()
        }
    }
    
    private func loadTrendsIfNeeded() {
        _Concurrency.Task {
            await viewModel.loadTrends(userId: userId)
        }
    }
    
    private func refreshBalances() {
        _Concurrency.Task {
            await viewModel.refreshBalances(userId: userId)
        }
    }
    
    // MARK: - Period Selector
    
    private var periodSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                periodButton(.week)
                periodButton(.month)
                periodButton(.quarter)
                periodButton(.halfYear)
                periodButton(.year)
            }
            .padding(.horizontal)
        }
    }
    
    private func periodButton(_ period: TrendPeriod) -> some View {
        Button(action: {
            viewModel.selectedPeriod = period
            loadTrendsIfNeeded()
        }) {
            Text(period.label)
                .font(.subheadline.bold())
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    viewModel.selectedPeriod == period
                        ? Color.accentColor
                        : Color(.systemGray5)
                )
                .foregroundColor(viewModel.selectedPeriod == period ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Summary Cards
    
    private func summaryCards(_ summary: TrendsSummaryDTO) -> some View {
        VStack(spacing: 12) {
            VStack(spacing: 8) {
                Text("Current Balance")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(formatCurrency(summary.currentBalance))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                
                TrendChangeView(
                    change: summary.netChange,
                    percent: summary.netChangePercent,
                    large: true
                )
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal)
            .background(Color(.systemBackground).opacity(0.8))
            .cornerRadius(20)
            .padding(.horizontal)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(
                    title: "Highest",
                    value: formatCurrency(summary.highestBalance),
                    subtitle: summary.highestBalanceDate,
                    color: .green
                )
                
                StatCard(
                    title: "Lowest",
                    value: formatCurrency(summary.lowestBalance),
                    subtitle: summary.lowestBalanceDate,
                    color: .red
                )
                
                StatCard(
                    title: "Average",
                    value: formatCurrency(summary.averageBalance),
                    subtitle: nil,
                    color: .blue
                )
                
                StatCard(
                    title: "Daily Change",
                    value: formatCurrency(summary.averageDailyChange),
                    subtitle: "\(summary.positiveDays)↑ \(summary.negativeDays)↓",
                    color: .purple
                )
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Balance Chart
    
    private func balanceChart(_ snapshots: [DailySnapshotDTO]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Balance Over Time")
                .font(.headline)
                .padding(.horizontal)
            
            GeometryReader { geo in
                let maxBalance = snapshots.map(\.totalBalance).max() ?? 1
                let minBalance = snapshots.map(\.totalBalance).min() ?? 0
                let range = max(maxBalance - minBalance, 1)
                
                HStack(alignment: .bottom, spacing: max(1, (geo.size.width - 40) / CGFloat(snapshots.count) - 4)) {
                    ForEach(0..<snapshots.count, id: \.self) { index in
                        let snapshot = snapshots[index]
                        let height = max(4, ((snapshot.totalBalance - minBalance) / range) * (geo.size.height - 20))
                        let isPositive = index > 0 ? snapshot.totalBalance >= snapshots[index - 1].totalBalance : true
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(isPositive ? Color.green.opacity(0.8) : Color.red.opacity(0.8))
                            .frame(height: height)
                    }
                }
                .padding(.horizontal, 20)
            }
            .frame(height: 120)
            
            if let first = snapshots.first, let last = snapshots.last {
                HStack {
                    Text(formatShortDate(first.date))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(formatShortDate(last.date))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .background(Color(.systemBackground).opacity(0.8))
        .cornerRadius(20)
        .padding(.horizontal)
    }
    
    // MARK: - Accounts Section
    
    private func accountsSection(_ accounts: [IndividualAccountTrendDTO]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("All Accounts")
                    .font(.headline)
                
                Spacer()
                
                Text("\(accounts.count)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            ForEach(accounts) { account in
                AccountTrendCard(account: account)
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Daily History Section
    
    private func dailyHistorySection(_ snapshots: [DailySnapshotDTO]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily History")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 0) {
                let reversed = Array(snapshots.reversed().prefix(10))
                ForEach(0..<reversed.count, id: \.self) { index in
                    let snapshot = reversed[index]
                    
                    if index > 0 {
                        Divider()
                            .padding(.leading, 16)
                    }
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(formatDate(snapshot.date))
                                .font(.subheadline)
                            
                            Text("\(snapshot.accountCount) accounts")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(formatCurrency(snapshot.totalBalance))
                                .font(.subheadline.monospacedDigit())
                            
                            if let change = snapshot.dailyChange {
                                TrendChangeView(change: change, percent: snapshot.dailyChangePercent, large: false)
                            }
                        }
                    }
                    .padding()
                }
            }
            .background(Color(.systemBackground).opacity(0.8))
            .cornerRadius(16)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading trends...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 100)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 40))
                    .foregroundColor(.accentColor)
            }
            
            VStack(spacing: 8) {
                Text("No Balance History")
                    .font(.title2.bold())
                
                Text("Refresh your balances to start tracking trends. We'll create daily snapshots to show how your balances change.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Button(action: refreshBalances) {
                Label("Refresh Balances", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isRefreshing)
        }
        .padding(.vertical, 60)
    }
    
    // MARK: - Helpers
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateString) {
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
        return dateString
    }
    
    private func formatShortDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateString) {
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
        return dateString
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
}

// MARK: - Supporting Views

private struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.headline.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground).opacity(0.8))
        .cornerRadius(14)
        .overlay(
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: 8, height: 8)
                .padding(12),
            alignment: .topTrailing
        )
    }
}

private struct TrendChangeView: View {
    let change: Double
    let percent: Double?
    let large: Bool
    
    private var isPositive: Bool { change >= 0 }
    private var color: Color { change == 0 ? .secondary : (isPositive ? .green : .red) }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: change == 0 ? "minus" : (isPositive ? "arrow.up.right" : "arrow.down.right"))
                .font(large ? .subheadline : .caption2)
            
            Text(formatChange())
                .font(large ? .subheadline.bold() : .caption)
        }
        .foregroundColor(color)
    }
    
    private func formatChange() -> String {
        let sign = change >= 0 ? "+" : ""
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        let changeStr = formatter.string(from: NSNumber(value: change)) ?? "$0.00"
        
        if let percent = percent {
            return "\(sign)\(changeStr) (\(sign)\(String(format: "%.1f", percent))%)"
        }
        return "\(sign)\(changeStr)"
    }
}

private struct AccountTrendCard: View {
    let account: IndividualAccountTrendDTO
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if let institution = account.institutionName {
                        Text(institution)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 4) {
                        Text(account.accountName)
                            .font(.subheadline.bold())
                        
                        if let mask = account.accountMask {
                            Text("••\(mask)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text(formatCurrency(account.currentBalance))
                        .font(.headline.monospacedDigit())
                }
                
                Spacer()
                
                TrendChangeView(change: account.netChange, percent: account.netChangePercent, large: false)
            }
            
            if let type = account.accountType {
                HStack {
                    Text(type.capitalized)
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5))
                        .clipShape(Capsule())
                    
                    Spacer()
                }
            }
            
            if !account.dataPoints.isEmpty {
                MiniBarChart(dataPoints: account.dataPoints)
                    .frame(height: 40)
            }
        }
        .padding()
        .background(Color(.systemBackground).opacity(0.8))
        .cornerRadius(16)
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
}

private struct MiniBarChart: View {
    let dataPoints: [DataPointDTO]
    
    var body: some View {
        GeometryReader { geo in
            let balances = dataPoints.map(\.balance)
            let maxBalance = balances.max() ?? 1
            let minBalance = balances.min() ?? 0
            let range = max(maxBalance - minBalance, 1)
            
            HStack(alignment: .bottom, spacing: max(1, (geo.size.width) / CGFloat(dataPoints.count) - 3)) {
                ForEach(0..<dataPoints.count, id: \.self) { index in
                    let point = dataPoints[index]
                    let height = max(2, ((point.balance - minBalance) / range) * geo.size.height)
                    let isPositive = index > 0 ? point.balance >= dataPoints[index - 1].balance : true
                    
                    RoundedRectangle(cornerRadius: 1)
                        .fill(isPositive ? Color.green.opacity(0.6) : Color.red.opacity(0.6))
                        .frame(height: height)
                }
            }
        }
    }
}

// MARK: - Trend Period

enum TrendPeriod: String, CaseIterable, Identifiable, Hashable {
    case week = "7"
    case month = "30"
    case quarter = "90"
    case halfYear = "180"
    case year = "365"
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .week: return "7 Days"
        case .month: return "30 Days"
        case .quarter: return "90 Days"
        case .halfYear: return "6 Months"
        case .year: return "1 Year"
        }
    }
    
    var days: Int {
        Int(rawValue) ?? 30
    }
}

// MARK: - View Model

@MainActor
final class BankAccountTrendsViewModel: ObservableObject {
    @Published var trendsData: BalanceTrendsResponseDTO?
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var selectedPeriod: TrendPeriod = .month
    @Published var errorMessage: String?
    
    func loadTrends(userId: String) async {
        guard !userId.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let client = AppAPIClient.live()
            let api = PlaidAPI(client: client)
            
            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .day, value: -selectedPeriod.days, to: endDate) ?? endDate
            
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            
            trendsData = try await api.getBalanceTrends(
                userId: userId,
                startDate: formatter.string(from: startDate),
                endDate: formatter.string(from: endDate)
            )
        } catch {
            errorMessage = "Failed to load trends: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func refreshBalances(userId: String) async {
        guard !userId.isEmpty else { return }
        
        isRefreshing = true
        
        do {
            let client = AppAPIClient.live()
            let api = PlaidAPI(client: client)
            
            _ = try await api.refreshBalances(userId: userId)
            await loadTrends(userId: userId)
        } catch {
            errorMessage = "Failed to refresh: \(error.localizedDescription)"
        }
        
        isRefreshing = false
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        BankAccountTrendsView()
    }
    .environment(\.injected, .previewAuthenticated)
}
