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
        LazyVStack(spacing: 0) {
            spendingTrendSection
            sectionDivider
            categoryBreakdownSection
            sectionDivider
            weeklyPatternSection
        }
        .padding(.top, 12)
        .padding(.bottom, 100)
        .task {
            if viewModel.analysisData == nil {
                await viewModel.loadAnalytics(userId: userId)
            }
        }
    }

    // MARK: - Section Divider

    private var sectionDivider: some View {
        Rectangle()
            .fill(Color.kBorder)
            .frame(height: 1)
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
    }

    // MARK: - Spending Trend

    private var spendingTrendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Editorial two-level header
            VStack(alignment: .leading, spacing: 2) {
                Text("SPENDING")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(2.0)
                    .foregroundStyle(Color.kTertiary)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Trend")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .tracking(-0.8)
                        .foregroundStyle(Color.kPrimary)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.kGreen)
                }
            }

            if let dailyData = viewModel.analysisData?.dailyBreakdown, !dailyData.isEmpty {
                Chart(dailyData) { day in
                    AreaMark(
                        x: .value("Date", parseDate(day.date)),
                        y: .value("Spending", day.spending)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.kPrimary.opacity(0.12), Color.kPrimary.opacity(0.01)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Date", parseDate(day.date)),
                        y: .value("Spending", day.spending)
                    )
                    .foregroundStyle(Color.kPrimary)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .foregroundStyle(Color.kBorderMedium)
                        AxisTick(stroke: StrokeStyle(lineWidth: 0))
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text(compactCurrency(amount))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(Color.kSecondary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .foregroundStyle(Color.kBorderMedium)
                        AxisTick(stroke: StrokeStyle(lineWidth: 0))
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.kSecondary)
                    }
                }
                .chartPlotStyle { plot in
                    plot.frame(height: 200)
                }
                .frame(height: 220)
            } else {
                KEmptyState(icon: "chart.line.uptrend.xyaxis", title: "No spending data")
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Category Breakdown

    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Editorial header
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("WHERE IT")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(2.0)
                        .foregroundStyle(Color.kTertiary)
                    Text("Goes")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .tracking(-0.8)
                        .foregroundStyle(Color.kPrimary)
                }
                Spacer()
            }

            if let categories = viewModel.analysisData?.topCategories, !categories.isEmpty {
                let top = Array(categories.prefix(5))
                let total = top.reduce(0) { $0 + $1.totalAmount }

                VStack(spacing: 0) {
                    // Proportion ribbon — one bar, all 5 colors side by side
                    GeometryReader { geo in
                        HStack(spacing: 2) {
                            ForEach(Array(top.enumerated()), id: \.element.id) { index, cat in
                                let ratio = total > 0 ? cat.totalAmount / total : 0
                                Capsule()
                                    .fill(paletteColor(index))
                                    .frame(width: max(6, geo.size.width * ratio))
                            }
                        }
                        .animation(.spring(response: 0.55, dampingFraction: 0.82), value: total)
                    }
                    .frame(height: 8)
                    .padding(.bottom, 22)

                    // Ranked rows
                    ForEach(Array(top.enumerated()), id: \.element.id) { index, cat in
                        categoryRow(cat: cat, total: total, index: index)
                        if index < top.count - 1 {
                            Rectangle().fill(Color.kBorder).frame(height: 1)
                        }
                    }
                }
            } else {
                KEmptyState(icon: "chart.pie", title: "No category data")
            }
        }
        .padding(.horizontal, 20)
    }

    private func categoryRow(cat: CategorySpendingDetailDTO, total: Double, index: Int) -> some View {
        let ratio = total > 0 ? cat.totalAmount / total : 0
        let color = paletteColor(index)

        return HStack(spacing: 12) {
            // Name + mini bar
            VStack(alignment: .leading, spacing: 5) {
                Text(cat.categoryName)
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(-0.2)
                    .foregroundStyle(Color.kPrimary)
                    .lineLimit(1)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(color.opacity(0.12))
                        Capsule()
                            .fill(color.opacity(0.7))
                            .frame(width: max(4, geo.size.width * ratio))
                            .animation(.spring(response: 0.5, dampingFraction: 0.8)
                                .delay(Double(index) * 0.06), value: ratio)
                    }
                }
                .frame(height: 3)
            }

            Spacer()

            // Pct + amount stacked right
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatCurrency(cat.totalAmount))
                    .font(.system(size: 14, weight: .bold))
                    .tracking(-0.5)
                    .foregroundStyle(Color.kPrimary)
                    .monospacedDigit()
                Text("\(Int(ratio * 100))%")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(color)
            }
        }
        .padding(.vertical, 12)
    }

    // MARK: - Weekly Pattern

    private var weeklyPatternSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Day of Week", icon: "calendar")

            if let weekData = viewModel.analysisData?.dayOfWeekBreakdown, !weekData.isEmpty {
                let maxVal = weekData.map(\.spending).max() ?? 1

                Chart(weekData) { day in
                    BarMark(
                        x: .value("Day", day.day),
                        y: .value("Spending", day.spending)
                    )
                    .foregroundStyle(
                        isToday(day.day) ? AnyShapeStyle(Color.kBlue) : AnyShapeStyle(Color.kDividerBg)
                    )
                    .cornerRadius(4)
                    .annotation(position: .top, spacing: 3) {
                        if day.spending > maxVal * 0.15 {
                            Text(compactCurrency(day.spending))
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(Color.kTertiary)
                        }
                    }
                }
                .chartYAxis(.hidden)
                .frame(height: 110)
            } else {
                KEmptyState(icon: "calendar", title: "No weekly data")
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Section Header

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.kTertiary)
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Color.kTertiary)
        }
    }

    // MARK: - Helpers

    private func formatCurrency(_ value: Double) -> String {
        value.formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }

    private func compactCurrency(_ value: Double) -> String {
        value >= 1000 ? "$\(Int(value / 1000))k" : "$\(Int(value))"
    }

    private func parseDate(_ dateString: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: dateString) { return d }
        f.formatOptions = [.withInternetDateTime]
        if let d = f.date(from: dateString) { return d }
        f.formatOptions = [.withFullDate]
        return f.date(from: dateString) ?? Date()
    }

    private func isToday(_ dayName: String) -> Bool {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: Date()) == dayName
    }

    private func categoryColor(for name: String) -> Color { Color.kPrimary }

    // Vivid, harmonious palette — distinct hues, consistent saturation
    private func paletteColor(_ index: Int) -> Color {
        let palette: [Color] = [
            Color(red: 0.13, green: 0.20, blue: 0.98),   // cobalt blue   #2133fa
            Color(red: 0.10, green: 0.72, blue: 0.55),   // emerald       #19b88c
            Color(red: 0.98, green: 0.62, blue: 0.12),   // amber         #fa9e1f
            Color(red: 0.93, green: 0.27, blue: 0.33),   // coral red     #ed4555
            Color(red: 0.60, green: 0.35, blue: 0.96),   // violet        #9959f5
        ]
        return palette[min(index, palette.count - 1)]
    }
}

#Preview {
    NavigationStack {
        TransactionsAnalyticsView(viewModel: TransactionsViewModel())
    }
    .environment(\.injected, .previewAuthenticated)
}
