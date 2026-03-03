import SwiftUI
import Charts

// MARK: - Transactions Analytics View

struct TransactionsAnalyticsView: View {
    @SwiftUI.Environment(\.injected) private var container: DIContainer
    @SwiftUI.Environment(\.colorScheme) private var colorScheme
    @Bindable var viewModel: TransactionsViewModel
    
    private var userId: String {
        container.appState.state.auth.user?.id ?? ""
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                heroStatsSection
                quickStatsSection
                spendingTrendSection
                categoryBreakdownSection
                weeklyPatternSection
                periodComparisonSection
                timeOfDaySection
                insightsSection
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
        .task {
            if viewModel.analysisData == nil {
                await viewModel.loadAnalytics(userId: userId)
            }
        }
    }
    
    // MARK: - Hero Stats
    
    private var heroStatsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
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
            
            netFlowCard
        }
    }
    
    private func statCard(title: String, value: String, subtitle: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Text(value)
                .font(.title3.bold().monospacedDigit())
            
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(tint.opacity(0.2), lineWidth: 1)
        }
    }
    
    private var netFlowCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "wallet.bifold.fill")
                    .font(.subheadline)
                    .foregroundStyle(.primary.opacity(0.7))
                Text("Net Cash Flow")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(viewModel.netCashFlow >= 0 ? "+" : "-")
                    .font(.title2.bold())
                Text(formatCurrency(abs(viewModel.netCashFlow)))
                    .font(.title2.bold().monospacedDigit())
            }
            .foregroundStyle(viewModel.netCashFlow >= 0 ? .green : .red)
            
            if let ratio = viewModel.spendingToIncomeRatio {
                VStack(alignment: .leading, spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(.quaternary)
                            Capsule()
                                .fill(ratio > 1 ? .red : ratio > 0.8 ? .orange : .green)
                                .frame(width: geo.size.width * min(ratio, 1.0))
                        }
                    }
                    .frame(height: 6)
                    
                    Text("\(Int(ratio * 100))% of income spent")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Quick Stats
    
    private var quickStatsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                quickStat(
                    icon: "doc.text.fill",
                    value: "\(viewModel.analysisData?.totalTransactions ?? (viewModel.expenseCount + viewModel.incomeCount))",
                    label: "Transactions"
                )
                
                quickStat(
                    icon: "divide.circle.fill",
                    value: formatCurrency(averageTransaction),
                    label: "Avg Transaction"
                )
                
                quickStat(
                    icon: "calendar.circle.fill",
                    value: formatCurrency(viewModel.analysisData?.averageDailySpending ?? 0),
                    label: "Daily Average"
                )
                
                if let busiestDay = viewModel.analysisData?.highestSpendingDay {
                    quickStat(
                        icon: "flame.fill",
                        value: formatShortDate(busiestDay),
                        label: "Busiest Day"
                    )
                }
                
                if let topCategory = viewModel.analysisData?.topCategories?.first {
                    quickStat(
                        icon: "tag.fill",
                        value: topCategory.categoryName,
                        label: "Top Category"
                    )
                }
            }
        }
        .scrollClipDisabled()
    }
    
    private func quickStat(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.tint)
            
            Text(value)
                .font(.subheadline.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 95)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
    
    // MARK: - Spending Trend Chart
    
    private var spendingTrendSection: some View {
        GlassCard(title: "Spending Trend", icon: "chart.line.uptrend.xyaxis.circle.fill") {
            if let dailyData = viewModel.analysisData?.dailyBreakdown, !dailyData.isEmpty {
                Chart(dailyData) { day in
                    AreaMark(
                        x: .value("Date", parseDate(day.date)),
                        y: .value("Spending", day.spending)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.red.opacity(0.4), .red.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                    
                    LineMark(
                        x: .value("Date", parseDate(day.date)),
                        y: .value("Spending", day.spending)
                    )
                    .foregroundStyle(.red)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .interpolationMethod(.catmullRom)
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(.quaternary)
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text(formatCompactCurrency(amount))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { value in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .font(.caption2)
                    }
                }
                .frame(height: 180)
            } else {
                ContentUnavailableView("No Data", systemImage: "chart.line.uptrend.xyaxis", description: Text("No spending data available"))
                    .frame(height: 180)
            }
        }
    }
    
    // MARK: - Category Breakdown
    
    private var categoryBreakdownSection: some View {
        GlassCard(title: "Spending by Category", icon: "chart.pie.fill") {
            if let categories = viewModel.analysisData?.topCategories, !categories.isEmpty {
                VStack(spacing: 16) {
                    Chart(categories) { category in
                        SectorMark(
                            angle: .value("Amount", category.totalAmount),
                            innerRadius: .ratio(0.55),
                            angularInset: 1.5
                        )
                        .foregroundStyle(by: .value("Category", category.categoryName))
                        .cornerRadius(4)
                    }
                    .chartLegend(.hidden)
                    .frame(height: 160)
                    
                    VStack(spacing: 10) {
                        ForEach(categories.prefix(5)) { category in
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(categoryColor(for: category.categoryName))
                                    .frame(width: 8, height: 8)
                                
                                Text(category.categoryName)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                Text(formatCurrency(category.totalAmount))
                                    .font(.subheadline.monospacedDigit())
                                
                                Text("\(Int(category.percentage))%")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 36, alignment: .trailing)
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView("No Categories", systemImage: "tag", description: Text("No category data available"))
                    .frame(height: 180)
            }
        }
    }
    
    // MARK: - Weekly Pattern
    
    private var weeklyPatternSection: some View {
        GlassCard(title: "Weekly Pattern", icon: "calendar.circle.fill") {
            if let weekData = viewModel.analysisData?.dayOfWeekBreakdown, !weekData.isEmpty {
                Chart(weekData) { day in
                    BarMark(
                        x: .value("Day", day.day),
                        y: .value("Spending", day.spending)
                    )
                    .foregroundStyle(
                        isToday(day.day) 
                            ? AnyShapeStyle(LinearGradient(colors: [.green, .green.opacity(0.6)], startPoint: .top, endPoint: .bottom))
                            : AnyShapeStyle(Color.secondary.opacity(0.4))
                    )
                    .cornerRadius(6)
                    .annotation(position: .top, spacing: 4) {
                        if day.spending > 0 {
                            Text(formatCompactCurrency(day.spending))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .chartYAxis(.hidden)
                .frame(height: 140)
            } else {
                ContentUnavailableView("No Data", systemImage: "calendar", description: Text("No weekly data available"))
                    .frame(height: 140)
            }
        }
    }
    
    // MARK: - Period Comparison
    
    @ViewBuilder
    private var periodComparisonSection: some View {
        if let comparison = viewModel.analysisData?.periodComparison {
            GlassCard(title: "Period Comparison", icon: "arrow.left.arrow.right.circle.fill") {
                VStack(spacing: 0) {
                    comparisonRow(
                        label: "Spending",
                        current: comparison.current.spending,
                        change: comparison.changes.spending,
                        invertColor: true
                    )
                    
                    Divider().padding(.vertical, 10)
                    
                    comparisonRow(
                        label: "Income",
                        current: comparison.current.income,
                        change: comparison.changes.income,
                        invertColor: false
                    )
                    
                    Divider().padding(.vertical, 10)
                    
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
            
            HStack(spacing: 3) {
                Image(systemName: change.isIncrease ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .font(.caption)
                Text("\(Int(change.percentage))%")
            }
            .font(.caption)
            .foregroundStyle(changeColor(isIncrease: change.isIncrease, invert: invertColor))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(changeColor(isIncrease: change.isIncrease, invert: invertColor).opacity(0.12), in: Capsule())
        }
    }
    
    // MARK: - Time of Day
    
    @ViewBuilder
    private var timeOfDaySection: some View {
        if let tod = viewModel.analysisData?.timeOfDayAnalysis {
            GlassCard(title: "When You Spend", icon: "clock.fill") {
                VStack(spacing: 12) {
                    if let peak = tod.peakSpendingTime {
                        HStack {
                            Spacer()
                            Label("Peak: \(peak)", systemImage: "sparkles")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(.quaternary, in: Capsule())
                        }
                    }
                    
                    timeOfDayRow(label: "Morning", timeRange: "6am - 12pm", slot: tod.morning, icon: "sunrise.fill")
                    timeOfDayRow(label: "Afternoon", timeRange: "12pm - 5pm", slot: tod.afternoon, icon: "sun.max.fill")
                    timeOfDayRow(label: "Evening", timeRange: "5pm - 9pm", slot: tod.evening, icon: "sunset.fill")
                    timeOfDayRow(label: "Night", timeRange: "9pm - 6am", slot: tod.night, icon: "moon.stars.fill")
                }
            }
        }
    }
    
    private func timeOfDayRow(label: String, timeRange: String, slot: TimeSlotDTO, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)
                Text(timeRange)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.quaternary)
                    Capsule()
                        .fill(.tint)
                        .frame(width: geo.size.width * (slot.percentage / 100))
                }
            }
            .frame(width: 50, height: 5)
            
            Text(formatCurrency(slot.totalSpending))
                .font(.caption.monospacedDigit())
                .frame(width: 65, alignment: .trailing)
            
            Text("\(Int(slot.percentage))%")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .trailing)
        }
    }
    
    // MARK: - Insights
    
    @ViewBuilder
    private var insightsSection: some View {
        if let insights = viewModel.analysisData?.spendingInsights, !insights.isEmpty {
            GlassCard(title: "Insights", icon: "lightbulb.fill") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(insights, id: \.self) { insight in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "sparkle")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                            Text(insight)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
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

// MARK: - Glass Card Component

private struct GlassCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(.tint)
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}

#Preview {
    NavigationStack {
        TransactionsAnalyticsView(viewModel: TransactionsViewModel())
    }
    .environment(\.injected, .previewAuthenticated)
}
