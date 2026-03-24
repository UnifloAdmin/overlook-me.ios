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
            LazyVStack(spacing: 10) {
                TransactionsPeriodPicker(viewModel: viewModel)
                TransactionsSummaryStrip(viewModel: viewModel)
                
                spendingTrendSection
                categoryBreakdownSection
                weeklyPatternSection
                periodComparisonSection
                timeOfDaySection
                insightsSection
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        }
        .background(Color.kSurface)
        .task {
            if viewModel.analysisData == nil {
                await viewModel.loadAnalytics(userId: userId)
            }
        }
    }
    
    // MARK: - Spending Trend Chart (neutral color, no red)
    
    private var spendingTrendSection: some View {
        KCard(title: "Spending Trend") {
            if let dailyData = viewModel.analysisData?.dailyBreakdown, !dailyData.isEmpty {
                Chart(dailyData) { day in
                    LineMark(
                        x: .value("Date", parseDate(day.date)),
                        y: .value("Spending", day.spending)
                    )
                    .foregroundStyle(Color.kPrimary.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                    .interpolationMethod(.catmullRom)
                    
                    PointMark(
                        x: .value("Date", parseDate(day.date)),
                        y: .value("Spending", day.spending)
                    )
                    .foregroundStyle(Color.kPrimary)
                    .symbolSize(day.spending > 0 ? 20 : 0)
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3]))
                            .foregroundStyle(Color.kBorder)
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text(formatCompactCurrency(amount))
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
    
    private var categoryBreakdownSection: some View {
        KCard(title: "Spending by Category") {
            if let categories = viewModel.analysisData?.topCategories, !categories.isEmpty {
                VStack(spacing: 12) {
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
                        ForEach(Array(categories.prefix(5).enumerated()), id: \.element.id) { index, category in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(categoryColor(for: category.categoryName))
                                    .frame(width: 6, height: 6)
                                
                                Text(category.categoryName)
                                    .font(.system(size: 12, weight: .semibold))
                                    .tracking(-0.1)
                                    .foregroundStyle(Color.kPrimary)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                // Percentage bar
                                KProgressBar(
                                    ratio: category.percentage / 100,
                                    color: categoryColor(for: category.categoryName),
                                    height: 3
                                )
                                .frame(width: 40)
                                
                                Text(formatCurrency(category.totalAmount))
                                    .font(.system(size: 12, weight: .semibold))
                                    .tracking(-0.1)
                                    .foregroundStyle(Color.kPrimary)
                                    .frame(width: 55, alignment: .trailing)
                                
                                Text("\(Int(category.percentage))%")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(Color.kTertiary)
                                    .frame(width: 30, alignment: .trailing)
                            }
                            .padding(.vertical, 6)
                            
                            if index < categories.prefix(5).count - 1 {
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
    
    // MARK: - Weekly Pattern
    
    private var weeklyPatternSection: some View {
        KCard(title: "Weekly Pattern") {
            if let weekData = viewModel.analysisData?.dayOfWeekBreakdown, !weekData.isEmpty {
                let maxSpending = weekData.map(\.spending).max() ?? 1
                
                Chart(weekData) { day in
                    BarMark(
                        x: .value("Day", day.day),
                        y: .value("Spending", day.spending)
                    )
                    .foregroundStyle(
                        isToday(day.day)
                            ? AnyShapeStyle(Color.kBlue)
                            : AnyShapeStyle(Color.kDividerBg)
                    )
                    .cornerRadius(4)
                    .annotation(position: .top, spacing: 3) {
                        if day.spending > maxSpending * 0.15 {
                            Text(formatCompactCurrency(day.spending))
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
    
    // MARK: - Period Comparison
    
    @ViewBuilder
    private var periodComparisonSection: some View {
        if let comparison = viewModel.analysisData?.periodComparison {
            KCard(title: "Period Comparison") {
                VStack(spacing: 0) {
                    comparisonRow(
                        label: "Spending",
                        current: comparison.current.spending,
                        change: comparison.changes.spending,
                        invertColor: true
                    )
                    
                    Rectangle().fill(Color.kBorder).frame(height: 1)
                        .padding(.vertical, 8)
                    
                    comparisonRow(
                        label: "Income",
                        current: comparison.current.income,
                        change: comparison.changes.income,
                        invertColor: false
                    )
                    
                    Rectangle().fill(Color.kBorder).frame(height: 1)
                        .padding(.vertical, 8)
                    
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
                .font(.system(size: 12, weight: .semibold))
                .tracking(-0.1)
                .foregroundStyle(Color.kSecondary)
            
            Spacer()
            
            Text(formatCurrency(current))
                .font(.system(size: 14, weight: .bold))
                .tracking(-0.3)
                .foregroundStyle(Color.kPrimary)
            
            HStack(spacing: 3) {
                Image(systemName: change.isIncrease ? "arrow.up" : "arrow.down")
                    .font(.system(size: 8, weight: .bold))
                Text("\(Int(change.percentage))%")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.4)
            }
            .foregroundStyle(changeColor(isIncrease: change.isIncrease, invert: invertColor))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(changeColor(isIncrease: change.isIncrease, invert: invertColor).opacity(0.1), in: Capsule())
        }
    }
    
    // MARK: - Time of Day
    
    @ViewBuilder
    private var timeOfDaySection: some View {
        if let tod = viewModel.analysisData?.timeOfDayAnalysis {
            KCard(title: "When You Spend") {
                VStack(spacing: 0) {
                    if let peak = tod.peakSpendingTime {
                        HStack {
                            Spacer()
                            KStatusBadge(text: "Peak: \(peak)", style: .pending)
                        }
                        .padding(.bottom, 8)
                    }
                    
                    timeOfDayRow(label: "Morning", timeRange: "6AM–12PM", slot: tod.morning, icon: "sunrise.fill")
                    Rectangle().fill(Color.kBorder).frame(height: 1).padding(.vertical, 5)
                    timeOfDayRow(label: "Afternoon", timeRange: "12PM–5PM", slot: tod.afternoon, icon: "sun.max.fill")
                    Rectangle().fill(Color.kBorder).frame(height: 1).padding(.vertical, 5)
                    timeOfDayRow(label: "Evening", timeRange: "5PM–9PM", slot: tod.evening, icon: "sunset.fill")
                    Rectangle().fill(Color.kBorder).frame(height: 1).padding(.vertical, 5)
                    timeOfDayRow(label: "Night", timeRange: "9PM–6AM", slot: tod.night, icon: "moon.stars.fill")
                }
            }
        }
    }
    
    private func timeOfDayRow(label: String, timeRange: String, slot: TimeSlotDTO, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(Color.kSecondary)
                .frame(width: 18)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(-0.1)
                    .foregroundStyle(Color.kPrimary)
                Text(timeRange)
                    .font(.system(size: 9, weight: .medium))
                    .tracking(0.2)
                    .foregroundStyle(Color.kTertiary)
            }
            
            Spacer()
            
            KProgressBar(ratio: slot.percentage / 100, color: Color.kPrimary.opacity(0.7))
                .frame(width: 44)
            
            Text(formatCurrency(slot.totalSpending))
                .font(.system(size: 12, weight: .semibold))
                .tracking(-0.1)
                .foregroundStyle(Color.kPrimary)
                .frame(width: 60, alignment: .trailing)
            
            Text("\(Int(slot.percentage))%")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.kTertiary)
                .frame(width: 28, alignment: .trailing)
        }
    }
    
    // MARK: - Insights (plain cards, no colored accents)
    
    @ViewBuilder
    private var insightsSection: some View {
        if let insights = viewModel.analysisData?.spendingInsights, !insights.isEmpty {
            KCard(title: "Insights") {
                VStack(spacing: 0) {
                    ForEach(Array(insights.enumerated()), id: \.offset) { index, insight in
                        HStack(spacing: 8) {
                            Image(systemName: "lightbulb")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.kTertiary)
                            
                            Text(insight)
                                .font(.system(size: 12, weight: .medium))
                                .tracking(-0.1)
                                .foregroundStyle(Color.kSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 8)
                        
                        if index < insights.count - 1 {
                            Rectangle().fill(Color.kBorder).frame(height: 1)
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
        let colors: [Color] = [Color.kBlue, Color.kGreen, .orange, Color.kRed, .purple, .teal, .pink, .indigo]
        let hash = abs(name.hashValue)
        return colors[hash % colors.count]
    }
    
    private func changeColor(isIncrease: Bool, invert: Bool) -> Color {
        let positive = invert ? !isIncrease : isIncrease
        return positive ? Color.kGreen : Color.kRed
    }
}

#Preview {
    NavigationStack {
        TransactionsAnalyticsView(viewModel: TransactionsViewModel())
    }
    .environment(\.injected, .previewAuthenticated)
}
