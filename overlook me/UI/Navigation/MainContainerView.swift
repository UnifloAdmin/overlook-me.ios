//
//  MainContainerView.swift
//  overlook me
//
//  Created by Naresh Chandra on 1/8/26.
//

import SwiftUI

struct MainContainerView: View {
    @StateObject private var tabBar = TabBarStyleStore()
    @State private var selection: AppTab = .home
    @State private var isMenuPresented = false

    // Keep navigation *inside* tabs so the tab bar stays visible.
    @State private var homePath = NavigationPath()

    // Shared ViewModel for Transactions tabs
    @State private var transactionsViewModel = TransactionsViewModel()

    // Track which health sub-route is active
    @State private var activeHealthRoute: SideNavRoute = .healthFitness

    var body: some View {
        TabView(selection: $selection) {
            Tab(tabBar.config.home.title, systemImage: tabBar.config.home.systemImage, value: .home) {
                homeTabContent()
                    .environmentObject(tabBar)
            }

            Tab(tabBar.config.explore.title, systemImage: tabBar.config.explore.systemImage, value: .explore) {
                exploreTabContent()
                    .environmentObject(tabBar)
            }

            if let alerts = tabBar.config.alerts {
                Tab(alerts.title, systemImage: alerts.systemImage, value: .notifications) {
                    alertsTabContent()
                        .environmentObject(tabBar)
                }
            }

            if let messages = tabBar.config.messages {
                Tab(messages.title, systemImage: messages.systemImage, value: .messages) {
                    messagesTabContent()
                        .environmentObject(tabBar)
                }
            } else if tabBar.config.preserveTrailingSlot {
                Tab(value: AppTab.messages) {
                    Color.clear
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                } label: {
                    Color.clear
                        .frame(width: 44, height: 44)
                        .accessibilityHidden(true)
                }
            }

            Tab("Menu", systemImage: "line.3.horizontal", value: AppTab.menu) {
                Color.clear
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .tabBarMinimizeBehavior(.never)
        .sheet(isPresented: $isMenuPresented) {
            SideNavigationView(onSelectRoute: { route in
                isMenuPresented = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    open(route)
                }
            })
        }
        .onChange(of: selection) { oldValue, newValue in
            if newValue == .menu {
                isMenuPresented = true
                selection = oldValue
                return
            }
            if tabBar.config.messages == nil && newValue == .messages {
                selection = oldValue
            }
            if tabBar.config.alerts == nil && newValue == .notifications {
                selection = oldValue
            }
        }
        .onChange(of: homePath) { _, newPath in
            if newPath.isEmpty && tabBar.config != .dailyHabits && tabBar.config != .tasks {
                tabBar.config = .default
            }
        }
        .onChange(of: tabBar.config) { oldValue, newValue in
            guard oldValue != newValue else { return }
            if newValue == .dailyHabits || newValue == .tasks || newValue == .health ||
               newValue == .budgets || newValue == .bankAccounts || newValue == .transactions ||
               newValue == .notifications || newValue == .dSprints {
                homePath = NavigationPath()
            }
            if (oldValue == .dailyHabits || oldValue == .tasks || oldValue == .health ||
                oldValue == .budgets || oldValue == .bankAccounts || oldValue == .transactions ||
                oldValue == .notifications || oldValue == .quitVape || oldValue == .dSprints)
                && newValue != oldValue {
                homePath = NavigationPath()
                selection = .home
            }
            if newValue.messages == nil && selection == .messages {
                selection = .home
            }
        }
    }

    private func open(_ route: SideNavRoute) {
        switch route {
        case .dailyHabits:
            switchMode(to: .dailyHabits)
        case .tasks:
            switchMode(to: .tasks)
        case .waterTracker, .reminders:
            pushRoute(route)
        case .healthDashboard, .healthInsights, .fitness,
             .healthSleep, .healthHeart, .healthMobility,
             .healthRespiration, .healthFitness, .healthExercise:
            activeHealthRoute = route
            if tabBar.config == .health {
                homePath = NavigationPath()
                selection = .home
            } else {
                switchMode(to: .health)
            }
        case .quitVape:
            switchMode(to: .quitVape)
        case .dSprints:
            switchMode(to: .dSprints)
        case .budgets:
            switchMode(to: .budgets)
        case .bankAccounts:
            switchMode(to: .bankAccounts)
        case .transactions:
            switchMode(to: .transactions)
        case .notificationManage:
            switchMode(to: .notifications)
        default:
            pushRoute(route)
        }
    }

    private func switchMode(to config: TabBarConfiguration) {
        guard tabBar.config != config else { return }
        homePath = NavigationPath()
        selection = .home
        tabBar.config = config
    }

    private func pushRoute(_ route: SideNavRoute) {
        let needsReset = tabBar.config != .default
        if needsReset {
            withAnimation(.easeInOut(duration: 0.3)) {
                tabBar.config = .default
            }
            selection = .home
            homePath = NavigationPath()
        } else {
            selection = .home
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + (needsReset ? 0.35 : 0.1)) {
            self.homePath.append(route)
        }
    }

    @ViewBuilder
    func homeTabContent() -> some View {
        if tabBar.config == .dSprints {
            NavigationStack {
                DSprintsView()
                    .tabBarConfig(.dSprints)
            }
        } else if tabBar.config == .budgets {
            NavigationStack {
                BudgetsView()
                    .tabBarConfig(.budgets)
            }
        } else if tabBar.config == .bankAccounts {
            NavigationStack {
                BankAccountsView()
                    .tabBarConfig(.bankAccounts)
            }
        } else if tabBar.config == .transactions {
            NavigationStack {
                TransactionsView(viewModel: transactionsViewModel, tab: .analytics)
            }
        } else if tabBar.config == .notifications {
            NavigationStack {
                NotificationsManageView()
                    .tabBarConfig(.notifications)
            }
        } else if tabBar.config == .health {
            NavigationStack {
                healthViewForRoute(activeHealthRoute)
                    .tabBarConfig(.health)
            }
        } else if tabBar.config == .quitVape {
            NavigationStack {
                QuitVapeView(activeTab: .log)
                    .tabBarConfig(.quitVape)
            }
        } else {
            HomeView(path: $homePath)
        }
    }

    @ViewBuilder
    func healthViewForRoute(_ route: SideNavRoute) -> some View {
        switch route {
        case .healthSleep:
            SleepView()
        case .healthHeart:
            HeartView()
        case .healthMobility:
            MobilityView()
        case .healthRespiration:
            RespirationView()
        case .healthExercise:
            ExerciseView()
        case .healthInsights:
            HealthInsightsView()
        case .quitVape:
            QuitVapeView()
        default:
            FitnessView()
        }
    }

    @ViewBuilder
    func exploreTabContent() -> some View {
        if tabBar.config == .dSprints {
            NavigationStack {
                DSprintsHistoryView()
                    .tabBarConfig(.dSprints)
            }
        } else if tabBar.config == .dailyHabits {
            NavigationStack {
                ChallengesTabView()
                    .tabBarConfig(.dailyHabits)
            }
        } else if tabBar.config == .tasks {
            NavigationStack {
                TaskBacklogsView()
                    .tabBarConfig(.tasks)
            }
        } else if tabBar.config == .bankAccounts {
            NavigationStack {
                BankAccountTrendsView()
                    .tabBarConfig(.bankAccounts)
            }
        } else if tabBar.config == .transactions {
            NavigationStack {
                TransactionsView(viewModel: transactionsViewModel, tab: .ledger)
            }
        } else if tabBar.config == .notifications {
            NavigationStack {
                DevicesManageView()
                    .tabBarConfig(.notifications)
            }
        } else if tabBar.config == .health {
            NavigationStack {
                Text("Trends")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.secondary)
                    .navigationTitle("Trends")
                    .tabBarConfig(.health)
            }
        } else if tabBar.config == .quitVape {
            NavigationStack {
                QuitVapeView(activeTab: .progress)
                    .tabBarConfig(.quitVape)
            }
        } else {
            NavigationStack {
                TodayPlaceholderView()
                    .tabBarConfig(.default)
            }
        }
    }

    @ViewBuilder
    func alertsTabContent() -> some View {
        if tabBar.config == .dailyHabits {
            NavigationStack {
                AnalyticsTabView()
                    .tabBarConfig(.dailyHabits)
            }
        } else if tabBar.config == .tasks {
            NavigationStack {
                TaskAnalyticsView()
                    .tabBarConfig(.tasks)
            }
        } else if tabBar.config == .transactions {
            NavigationStack {
                TransactionsView(viewModel: transactionsViewModel, tab: .merchants)
            }
        } else if tabBar.config == .health {
            NavigationStack {
                Text("Trends")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.secondary)
                    .navigationTitle("Trends")
                    .tabBarConfig(.health)
            }
        } else if tabBar.config == .quitVape {
            NavigationStack {
                QuitVapeView(activeTab: .health)
                    .tabBarConfig(.quitVape)
            }
        } else {
            NavigationStack {
                HealthInsightsView()
                    .tabBarConfig(.default)
            }
        }
    }

    @ViewBuilder
    func messagesTabContent() -> some View {
        if tabBar.config == .dailyHabits {
            NavigationStack {
                AddNewHabitTabView()
                    .tabBarConfig(.dailyHabits)
            }
        } else if tabBar.config == .transactions {
            NavigationStack {
                TransactionsView(viewModel: transactionsViewModel, tab: .search)
            }
        } else {
            NavigationStack {
                FinancesView()
                    .tabBarConfig(.default)
            }
        }
    }
}

// MARK: - Tab Selection

private enum AppTab: Hashable {
    case home
    case explore
    case notifications
    case messages
    case menu
}

// MARK: - Today Placeholder

private struct TodayPlaceholderView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Kalshi.textMuted)
            Text("Today")
                .kalshiCardTitle()
            Text("Your daily overview is coming soon.")
                .kalshiSecondary()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Kalshi.bg)
    }
}

// MARK: - Preview

#Preview {
    MainContainerView()
        .environment(\.injected, .previewAuthenticated)
}
