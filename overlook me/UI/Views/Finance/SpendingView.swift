import SwiftUI
import Charts

// MARK: - Spending View

struct SpendingView: View {
    @SwiftUI.Environment(\.injected) private var container: DIContainer
    @State private var viewModel = TransactionsViewModel()
    
    private var userId: String {
        container.appState.state.auth.user?.id ?? ""
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                TransactionsPeriodPicker(viewModel: viewModel)
                TransactionsSummaryStrip(viewModel: viewModel)
                
                spendingTrendCard
                categoryBreakdownCard
                topMerchantsCard
                weeklyPatternCard
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        }
        .background(Color.kSurface)
        .navigationTitle("Spending")
        .toolbarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadAnalytics(userId: userId)
            await viewModel.loadMerchants(userId: userId)
        }
        .onChange(of: viewModel.viewMode) { _, _ in reload() }
        .onChange(of: viewModel.periodOffset) { _, _ in reload() }
    }
    
    private func reload() {
        let uid = userId
        let vm = viewModel
        _Concurrency.Task {
            await vm.loadAnalytics(userId: uid)
            await vm.loadMerchants(userId: uid)
        }
    }
    
    // MARK: - Spending Trend
    
    private var spendingTrendCard: some View {
        KCard(title: "Spending Trend") {
            if let dailyData = viewModel.analysisData?.dailyBreakdown, !dailyData.isEmpty {
                Chart(dailyData) { day in
                    AreaMark(
                        x: .value("Date", parseDate(day.date)),
                        y: .value("Spending", day.spending)
                    )
                    .foregroundStyle(Color.kPrimary.opacity(0.08))
                    .interpolationMethod(.catmullRom)
                    
                    LineMark(
                        x: .value("Date", parseDate(day.date)),
                        y: .value("Spending", day.spending)
                    )
                    .foregroundStyle(Color.kPrimary.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                    .interpolationMethod(.catmullRom)
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3]))
                            .foregroundStyle(Color.kBorder)
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text(formatCompact(amount))
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
            } else {
                KEmptyState(icon: "chart.line.uptrend.xyaxis", title: "No spending data", message: "Spending trend will appear here")
            }
        }
    }
    
    // MARK: - Category Breakdown
    
    private var categoryBreakdownCard: some View {
        KCard(title: "By Category") {
            if let categories = viewModel.analysisData?.topCategories, !categories.isEmpty {
                VStack(spacing: 10) {
                    Chart(categories) { category in
                        SectorMark(
                            angle: .value("Amount", category.totalAmount),
                            innerRadius: .ratio(0.6),
                            angularInset: 1.5
                        )
                        .foregroundStyle(by: .value("Category", category.categoryName))
                        .cornerRadius(3)
                    }
                    .chartLegend(.hidden)
                    .frame(height: 140)
                    
                    VStack(spacing: 0) {
                        ForEach(Array(categories.prefix(6).enumerated()), id: \.element.id) { index, cat in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(categoryColor(for: cat.categoryName))
                                    .frame(width: 6, height: 6)
                                
                                Text(cat.categoryName)
                                    .font(.system(size: 12, weight: .semibold))
                                    .tracking(-0.1)
                                    .foregroundStyle(Color.kPrimary)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                Text(formatCurrency(cat.totalAmount))
                                    .font(.system(size: 12, weight: .semibold))
                                    .tracking(-0.1)
                                    .foregroundStyle(Color.kPrimary)
                                    .frame(width: 55, alignment: .trailing)
                                
                                Text("\(Int(cat.percentage))%")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(Color.kTertiary)
                                    .frame(width: 30, alignment: .trailing)
                            }
                            .padding(.vertical, 6)
                            
                            if index < categories.prefix(6).count - 1 {
                                Rectangle()
                                    .fill(Color.kBorder)
                                    .frame(height: 1)
                            }
                        }
                    }
                }
            } else {
                KEmptyState(icon: "tag", title: "No category data", message: "Category breakdown will appear here")
            }
        }
    }
    
    // MARK: - Top Merchants
    
    private var topMerchantsCard: some View {
        KCard(title: "Top Merchants") {
            if !viewModel.merchantSummaries.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.merchantSummaries.prefix(5).enumerated()), id: \.element.name) { index, merchant in
                        HStack(spacing: 10) {
                            Text("\(index + 1)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.kTertiary)
                                .frame(width: 16)
                            
                            Text(merchant.name)
                                .font(.system(size: 12, weight: .semibold))
                                .tracking(-0.1)
                                .foregroundStyle(Color.kPrimary)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text("\(merchant.transactionCount) txn")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color.kTertiary)
                            
                            Text(formatCurrency(merchant.totalSpent))
                                .font(.system(size: 12, weight: .semibold))
                                .tracking(-0.1)
                                .foregroundStyle(Color.kPrimary)
                                .frame(width: 60, alignment: .trailing)
                        }
                        .padding(.vertical, 7)
                        
                        if index < viewModel.merchantSummaries.prefix(5).count - 1 {
                            Rectangle()
                                .fill(Color.kBorder)
                                .frame(height: 1)
                        }
                    }
                }
            } else {
                KEmptyState(icon: "storefront", title: "No merchant data", message: "Top merchants will appear here")
            }
        }
    }
    
    // MARK: - Weekly Pattern
    
    private var weeklyPatternCard: some View {
        KCard(title: "Weekly Pattern") {
            if let weekData = viewModel.analysisData?.dayOfWeekBreakdown, !weekData.isEmpty {
                Chart(weekData) { day in
                    BarMark(
                        x: .value("Day", day.day),
                        y: .value("Spending", day.spending)
                    )
                    .foregroundStyle(Color.kDividerBg)
                    .cornerRadius(4)
                    .annotation(position: .top, spacing: 3) {
                        let maxSpending = weekData.map(\.spending).max() ?? 1
                        if day.spending > maxSpending * 0.15 {
                            Text(formatCompact(day.spending))
                                .font(.system(size: 8, weight: .semibold))
                                .tracking(0.2)
                                .foregroundStyle(Color.kTertiary)
                        }
                    }
                }
                .chartYAxis(.hidden)
                .frame(height: 120)
            } else {
                KEmptyState(icon: "calendar", title: "No weekly data", message: "Weekly spending pattern will appear here")
            }
        }
    }
    
    // MARK: - Helpers
    
    private func formatCurrency(_ value: Double) -> String {
        value.formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }
    
    private func formatCompact(_ value: Double) -> String {
        if value >= 1000 { return "$\(Int(value / 1000))k" }
        return "$\(Int(value))"
    }
    
    private func parseDate(_ dateString: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) { return date }
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: dateString) ?? Date()
    }
    
    private func categoryColor(for name: String) -> Color {
        let colors: [Color] = [Color.kBlue, Color.kGreen, .orange, Color.kRed, .purple, .teal, .pink, .indigo]
        let hash = abs(name.hashValue)
        return colors[hash % colors.count]
    }
}

#Preview {
    NavigationStack {
        SpendingView()
    }
    .environment(\.injected, .previewAuthenticated)
}
