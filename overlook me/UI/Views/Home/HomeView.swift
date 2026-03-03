import SwiftUI

struct HomeView: View {
    @Binding var path: NavigationPath
    @EnvironmentObject private var tabBar: TabBarStyleStore
    @State private var transactionsViewModel = TransactionsViewModel()

    var body: some View {
        NavigationStack(path: $path) {
            rootView
                .navigationDestination(for: SideNavRoute.self) { route in
                    destination(for: route)
                }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private var rootView: some View {
        if tabBar.config == .dailyHabits {
            DailyHabitsView()
                .tabBarConfig(.dailyHabits)
                .toolbar(.visible, for: .navigationBar)
                .id("dailyHabits")
        } else if tabBar.config == .tasks {
            TaskDashboard()
                .tabBarConfig(.tasks)
                .toolbar(.visible, for: .navigationBar)
                .id("tasks")
        } else {
            landingView
                .tabBarConfig(.default)
                .toolbar(.hidden, for: .navigationBar)
                .id("landing")
        }
    }

    private var landingView: some View {
        AdaptiveHomeDashboard()
    }
    
    @ViewBuilder
    private func destination(for route: SideNavRoute) -> some View {
        switch route {
        case .homeDashboard:
            landingView
                .toolbar(.hidden, for: .navigationBar)

        case .weeklyInsights:
            Text("Weekly Insights")
                .toolbar(.visible, for: .navigationBar)

        case .financeDashboard:
            FinanceDashboardView()
                .toolbar(.visible, for: .navigationBar)
        case .bankAccounts:
            BankAccountsView()
                .toolbar(.visible, for: .navigationBar)
        case .trends:
            TrendsView()
                .toolbar(.visible, for: .navigationBar)
        case .transactions:
            TransactionsView(viewModel: transactionsViewModel, tab: .analytics)
                .toolbar(.visible, for: .navigationBar)
        case .budgets:
            BudgetsView()
                .toolbar(.visible, for: .navigationBar)
        case .insights:
            InsightsView()
                .toolbar(.visible, for: .navigationBar)
        case .netWorth:
            NetWorthView()
                .toolbar(.visible, for: .navigationBar)

        case .productivityDashboard:
            ProductivityDashboardView()
                .toolbar(.visible, for: .navigationBar)
        case .tasks, .dailyHabits:
            EmptyView()

        case .healthDashboard, .healthInsights:
            HealthInsightsView()
                .toolbar(.visible, for: .navigationBar)
        case .fitness:
            FitnessView()
                .toolbar(.visible, for: .navigationBar)

        case .mySubscriptions:
            RecurringPaymentsView()
                .toolbar(.visible, for: .navigationBar)
        case .managePlan:
            ManagePlanView()
                .toolbar(.visible, for: .navigationBar)
        case .notificationManage:
            NotificationsManageView()
                .toolbar(.visible, for: .navigationBar)
        case .friendCircle:
            Text("My Friend Circle")
                .toolbar(.visible, for: .navigationBar)
        }
    }
}
