import SwiftUI

struct HomeDashboardView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var weather = WeatherData.placeholder
    
    var onTasksTap: () -> Void = {}
    var onHabitsTap: () -> Void = {}
    var onSpendingTap: () -> Void = {}
    var onScheduleTap: () -> Void = {}
    var onBudgetsTap: () -> Void = {}
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Header
                headerSection
                
                // Quick Stats
                statsSection
                
                // Main Content
                VStack(spacing: 12) {
                    // Today's Focus
                    todaySection
                    
                    // Productivity
                    productivitySection
                    
                    // Finance
                    financeSection
                    
                    // Wellness
                    wellnessSection
                    
                    // Daily Life
                    dailySection
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
        .contentMargins(.top, 0, for: .scrollIndicators)
        .scrollContentBackground(.hidden)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(viewModel.greeting)
                .font(.largeTitle.bold())
            
            Text(viewModel.todayDateString)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Stats
    
    private var statsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                CompactStatTile(icon: "checkmark.circle.fill", color: .indigo, value: "\(viewModel.taskStats.completed)/\(viewModel.taskStats.total)", label: "Tasks", action: onTasksTap)
                CompactStatTile(icon: "flame.fill", color: .orange, value: "\(viewModel.habitStats.streaks)", label: "Streaks", action: onHabitsTap)
                CompactStatTile(icon: "wallet.pass.fill", color: .green, value: viewModel.formatCurrency(viewModel.spendingStats.thisMonth), label: "Spent", action: onSpendingTap)
                CompactStatTile(icon: "figure.walk", color: .pink, value: viewModel.exerciseData.steps.formatted(), label: "Steps", action: {})
            }
        }
        .scrollClipDisabled()
    }
    
    // MARK: - Today Section
    
    private var todaySection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                WeatherTile(weather: weather, onTap: {})
                ScheduleTile(schedule: viewModel.schedule, onTap: onScheduleTap)
            }
            .fixedSize(horizontal: false, vertical: true)
            
            FocusTile(tasks: viewModel.focusTasks, onTap: onTasksTap)
        }
    }
    
    // MARK: - Productivity Section
    
    private var productivitySection: some View {
        VStack(spacing: 12) {
            WeekGlanceTile(days: viewModel.weekDays, onTap: onScheduleTap)
            
            HStack(spacing: 12) {
                HabitsTile(stats: viewModel.habitStats, onTap: onHabitsTap)
                MoodTile(mood: viewModel.moodData, onTap: {})
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    // MARK: - Finance Section
    
    private var financeSection: some View {
        VStack(spacing: 12) {
            SpendingTile(
                weeklySpending: viewModel.weeklySpending,
                totalFormatted: viewModel.formatCurrency(viewModel.weeklySpending.reduce(0) { $0 + $1.amount }),
                onTap: onSpendingTap
            )
            
            HStack(spacing: 12) {
                BudgetsTile(budgets: viewModel.budgets, onTap: onBudgetsTap)
                BillsTile(bills: viewModel.upcomingBills, onTap: onSpendingTap)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    // MARK: - Wellness Section
    
    private var wellnessSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                SleepTile(data: viewModel.sleepData, onTap: {})
                HeartTile(data: viewModel.heartData, onTap: {})
            }
            .fixedSize(horizontal: false, vertical: true)
            
            HStack(spacing: 12) {
                ActivityTile(data: viewModel.exerciseData, onTap: {})
                ScreenTimeTile(data: viewModel.screenTime, onTap: {})
            }
            .fixedSize(horizontal: false, vertical: true)
            
            WaterIntakeTile(waterIntake: viewModel.waterIntake, onTap: {})
        }
    }
    
    // MARK: - Daily Section
    
    private var dailySection: some View {
        VStack(spacing: 12) {
            QuoteTile(quote: viewModel.dailyQuote, onTap: {})
            QuickActionsTile(
                onAddTask: onTasksTap,
                onHabits: onHabitsTap,
                onCalendar: onScheduleTap,
                onBudgets: onBudgetsTap
            )
        }
    }
}

// MARK: - Compact Stat Tile

private struct CompactStatTile: View {
    let icon: String
    let color: Color
    let value: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                    .frame(width: 36, height: 36)
                    .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(value)
                        .font(.subheadline.bold())
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Adaptive (kept for compatibility)

struct AdaptiveHomeDashboard: View {
    var onTasksTap: () -> Void = {}
    var onHabitsTap: () -> Void = {}
    var onSpendingTap: () -> Void = {}
    var onScheduleTap: () -> Void = {}
    var onBudgetsTap: () -> Void = {}
    
    var body: some View {
        HomeDashboardView(
            onTasksTap: onTasksTap,
            onHabitsTap: onHabitsTap,
            onSpendingTap: onSpendingTap,
            onScheduleTap: onScheduleTap,
            onBudgetsTap: onBudgetsTap
        )
    }
}

#Preview {
    HomeDashboardView()
}
