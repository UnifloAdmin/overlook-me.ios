import SwiftUI
import Charts

// MARK: - Transactions Analytics View

struct TransactionsAnalyticsView: View {
    @SwiftUI.Environment(\.injected) private var container: DIContainer
    @Bindable var viewModel: TransactionsViewModel
    
    private var userId: String {
        container.appState.state.auth.user?.id ?? ""
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                heroStatsSection
                quickStatsSection
                spendingTrendSection
                categoryBreakdownSection
                weeklyPatternSection
                periodComparisonSection
                timeOfDaySection
                insightsSection
            }
            .padding()
        }
        .task {
            if viewModel.analysisData == nil {
                await viewModel.loadAnalytics(userId: userId)
            }
        }
    }
    
    // MARK: - Hero Stats
    
    private var heroStatsSection: some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                statCard(
                    title: "Total Spent",
                    value: formatCurrency(viewModel.totalSpent),
                    subtitle: "\(viewModel.expenseCount) transactions",
                    icon: "arrow.up.circle.fill",
                    tint: .red
                )
                
                statCard(
                    title: "Total Income",
                    value: formatCurrency(viewModel.totalIncome),
                    subtitle: "\(viewModel.incomeCount) deposits",
                    icon: "arrow.down.circle.fill",
                    tint: .green
                )
            }
            
            GridRow {
                netFlowCard
                    .gridCellColumns(2)
            }
        }
    }
    
    private func statCard(title: String, value: String, subtitle: String, icon: String, tint: Color) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Label(title, systemImage: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(value)
                    .font(.title2.bold().monospacedDigit())
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .backgroundStyle(tint.opacity(0.1))
    }
    
    private var netFlowCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Label("Net Cash Flow", systemImage: "wallet.bifold.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack {
                    Text(viewModel.netCashFlow >= 0 ? "+" : "")
                        .font(.title2.bold()) +
                    Text(formatCurrency(abs(viewModel.netCashFlow)))
                        .font(.title2.bold().monospacedDigit())
                }
                .foregroundStyle(viewModel.netCashFlow >= 0 ? .green : .red)
                
                if let ratio = viewModel.spendingToIncomeRatio {
                    ProgressView(value: min(ratio, 1.0)) {
                        Text("\(Int(ratio * 100))% of income spent")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .tint(ratio > 1 ? .red : ratio > 0.8 ? .orange : .green)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    // MARK: - Quick Stats
    
    private var quickStatsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                quickStat(
                    icon: "doc.text",
                    value: "\(viewModel.analysisData?.totalTransactions ?? (viewModel.expenseCount + viewModel.incomeCount))",
                    label: "Transactions"
                )
                
                quickStat(
                    icon: "divide",
                    value: formatCurrency(averageTransaction),
                    label: "Avg Transaction"
                )
                
                quickStat(
                    icon: "calendar",
                    value: formatCurrency(viewModel.analysisData?.averageDailySpending ?? 0),
                    label: "Daily Average"
                )
                
                if let busiestDay = viewModel.analysisData?.highestSpendingDay {
                    quickStat(
                        icon: "flame",
                        value: formatShortDate(busiestDay),
                        label: "Busiest Day"
                    )
                }
                
                if let topCategory = viewModel.analysisData?.topCategories?.first {
                    quickStat(
                        icon: "tag",
                        value: topCategory.categoryName,
                        label: "Top Category"
                    )
                }
            }
            .padding(.horizontal, 1)
        }
    }
    
    private func quickStat(icon: String, value: String, label: String) -> some View {
        GroupBox {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.tint)
                
                Text(value)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 90)
        }
    }
    
    // MARK: - Spending Trend Chart
    
    private var spendingTrendSection: some View {
        GroupBox("Spending Trend") {
            if let dailyData = viewModel.analysisData?.dailyBreakdown, !dailyData.isEmpty {
                Chart(dailyData) { day in
                    AreaMark(
                        x: .value("Date", parseDate(day.date)),
                        y: .value("Spending", day.spending)
                    )
                    .foregroundStyle(.red.opacity(0.3))
                    
                    LineMark(
                        x: .value("Date", parseDate(day.date)),
                        y: .value("Spending", day.spending)
                    )
                    .foregroundStyle(.red)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text(formatCompactCurrency(amount))
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { value in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .frame(height: 200)
            } else {
                ContentUnavailableView("No Data", systemImage: "chart.line.uptrend.xyaxis", description: Text("No spending data available"))
                    .frame(height: 200)
            }
        }
    }
    
    // MARK: - Category Breakdown
    
    private var categoryBreakdownSection: some View {
        GroupBox("Spending by Category") {
            if let categories = viewModel.analysisData?.topCategories, !categories.isEmpty {
                VStack(spacing: 16) {
                    Chart(categories) { category in
                        SectorMark(
                            angle: .value("Amount", category.totalAmount),
                            innerRadius: .ratio(0.6),
                            angularInset: 2
                        )
                        .foregroundStyle(by: .value("Category", category.categoryName))
                        .annotation(position: .overlay) {
                            if category.percentage > 10 {
                                Text("\(Int(category.percentage))%")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .chartLegend(.hidden)
                    .frame(height: 180)
                    
                    ForEach(categories.prefix(5)) { category in
                        HStack {
                            Circle()
                                .fill(categoryColor(for: category.categoryName))
                                .frame(width: 10, height: 10)
                            
                            Text(category.categoryName)
                                .font(.subheadline)
                            
                            Spacer()
                            
                            Text(formatCurrency(category.totalAmount))
                                .font(.subheadline.monospacedDigit())
                            
                            Text("\(Int(category.percentage))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 40, alignment: .trailing)
                        }
                    }
                }
            } else {
                ContentUnavailableView("No Categories", systemImage: "tag", description: Text("No category data available"))
                    .frame(height: 200)
            }
        }
    }
    
    // MARK: - Weekly Pattern
    
    private var weeklyPatternSection: some View {
        GroupBox("Weekly Pattern") {
            if let weekData = viewModel.analysisData?.dayOfWeekBreakdown, !weekData.isEmpty {
                Chart(weekData) { day in
                    BarMark(
                        x: .value("Day", day.day),
                        y: .value("Spending", day.spending)
                    )
                    .foregroundStyle(isToday(day.day) ? .green : .secondary.opacity(0.5))
                    .cornerRadius(4)
                    .annotation(position: .top) {
                        if day.spending > 0 {
                            Text(formatCompactCurrency(day.spending))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .chartYAxis(.hidden)
                .frame(height: 160)
            } else {
                ContentUnavailableView("No Data", systemImage: "calendar", description: Text("No weekly data available"))
                    .frame(height: 160)
            }
        }
    }
    
    // MARK: - Period Comparison
    
    @ViewBuilder
    private var periodComparisonSection: some View {
        if let comparison = viewModel.analysisData?.periodComparison {
            GroupBox("Period Comparison") {
                VStack(spacing: 12) {
                    comparisonRow(
                        label: "Spending",
                        current: comparison.current.spending,
                        change: comparison.changes.spending,
                        invertColor: true
                    )
                    
                    Divider()
                    
                    comparisonRow(
                        label: "Income",
                        current: comparison.current.income,
                        change: comparison.changes.income,
                        invertColor: false
                    )
                    
                    Divider()
                    
                    comparisonRow(
                        label: "Net Flow",
                        current: comparison.current.netFlow,
                        change: comparison.changes.netFlow,
                        invertColor: false
                    )
                }
            }
        }
    }
    
    private func comparisonRow(label: String, current: Double, change: ChangeMetricDTO, invertColor: Bool) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
            
            Spacer()
            
            Text(formatCurrency(current))
                .font(.subheadline.bold().monospacedDigit())
            
            HStack(spacing: 2) {
                Image(systemName: change.isIncrease ? "arrow.up" : "arrow.down")
                Text("\(Int(change.percentage))%")
            }
            .font(.caption)
            .foregroundStyle(changeColor(isIncrease: change.isIncrease, invert: invertColor))
        }
    }
    
    // MARK: - Time of Day
    
    @ViewBuilder
    private var timeOfDaySection: some View {
        if let tod = viewModel.analysisData?.timeOfDayAnalysis {
            GroupBox("When You Spend") {
                VStack(spacing: 8) {
                    if let peak = tod.peakSpendingTime {
                        Label("Peak: \(peak)", systemImage: "clock.badge.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    
                    timeOfDayRow(label: "Morning", timeRange: "6am - 12pm", slot: tod.morning, icon: "sunrise")
                    timeOfDayRow(label: "Afternoon", timeRange: "12pm - 5pm", slot: tod.afternoon, icon: "sun.max")
                    timeOfDayRow(label: "Evening", timeRange: "5pm - 9pm", slot: tod.evening, icon: "sunset")
                    timeOfDayRow(label: "Night", timeRange: "9pm - 6am", slot: tod.night, icon: "moon.stars")
                }
            }
        }
    }
    
    private func timeOfDayRow(label: String, timeRange: String, slot: TimeSlotDTO, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(.tint)
            
            VStack(alignment: .leading) {
                Text(label)
                    .font(.subheadline)
                Text(timeRange)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            ProgressView(value: slot.percentage / 100)
                .frame(width: 60)
            
            Text(formatCurrency(slot.totalSpending))
                .font(.caption.monospacedDigit())
                .frame(width: 70, alignment: .trailing)
            
            Text("\(Int(slot.percentage))%")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 35, alignment: .trailing)
        }
    }
    
    // MARK: - Insights
    
    @ViewBuilder
    private var insightsSection: some View {
        if let insights = viewModel.analysisData?.spendingInsights, !insights.isEmpty {
            GroupBox("Insights") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(insights, id: \.self) { insight in
                        Label(insight, systemImage: "info.circle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private var averageTransaction: Double {
        guard viewModel.expenseCount > 0 else { return 0 }
        return viewModel.totalSpent / Double(viewModel.expenseCount)
    }
    
    private func formatCurrency(_ value: Double) -> String {
        value.formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }
    
    private func formatCompactCurrency(_ value: Double) -> String {
        if value >= 1000 {
            return "$\(Int(value / 1000))k"
        }
        return "$\(Int(value))"
    }
    
    private func formatShortDate(_ dateString: String) -> String {
        let date = parseDate(dateString)
        return date.formatted(.dateTime.month(.abbreviated).day())
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
    
    private func isToday(_ dayName: String) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: Date()) == dayName
    }
    
    private func categoryColor(for name: String) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .red, .purple, .teal, .pink, .indigo]
        let hash = abs(name.hashValue)
        return colors[hash % colors.count]
    }
    
    private func changeColor(isIncrease: Bool, invert: Bool) -> Color {
        let positive = invert ? !isIncrease : isIncrease
        return positive ? .green : .red
    }
}

#Preview {
    NavigationStack {
        TransactionsAnalyticsView(viewModel: TransactionsViewModel())
    }
    .environment(\.injected, .previewAuthenticated)
}
