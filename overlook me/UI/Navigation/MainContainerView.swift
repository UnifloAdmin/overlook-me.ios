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
    @State private var showingSideNav = false
    @State private var pendingNavigation: SideNavRoute?
    
    // Keep navigation *inside* tabs so the tab bar stays visible.
    @State private var homePath = NavigationPath()
    
    // Shared ViewModel for Transactions tabs
    @State private var transactionsViewModel = TransactionsViewModel()
    
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
            
            // Native “separate” trailing button, like Apple News.
            // We use the system role so iOS renders it as the detached pill/button.
            Tab(value: .searchProxy, role: .search) {
                Color.clear
            }
        }
        .tabBarMinimizeBehavior(.never)
        .sheet(isPresented: $showingSideNav, onDismiss: {
            guard let pendingRoute = pendingNavigation else { return }
            pendingNavigation = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                open(pendingRoute)
            }
        }) {
            SideNavigationView(
                isPresented: $showingSideNav,
                onSelectRoute: { route in
                    pendingNavigation = route
                }
            )
        }
        .onChange(of: selection) { oldValue, newValue in
            if newValue == .searchProxy {
                showingSideNav = true
                selection = oldValue == .searchProxy ? .home : oldValue
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
            // Reset tab bar config when user pops all the way back to the landing screen
            if newPath.isEmpty && tabBar.config != .dailyHabits && tabBar.config != .tasks {
                tabBar.config = .default
            }
        }
        .onChange(of: tabBar.config) { oldValue, newValue in
            guard oldValue != newValue else { return }
            if newValue == .dailyHabits || newValue == .tasks || newValue == .health ||
               newValue == .bankAccounts || newValue == .transactions || newValue == .notifications {
                homePath = NavigationPath()
            }
            if (oldValue == .dailyHabits || oldValue == .tasks || oldValue == .health ||
                oldValue == .bankAccounts || oldValue == .transactions || oldValue == .notifications)
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
        case .healthDashboard, .healthInsights, .fitness:
            switchMode(to: .health)
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
        withAnimation(.easeInOut(duration: 0.3)) {
            tabBar.config = config
        }
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
        if tabBar.config == .bankAccounts {
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
                FitnessView()
                    .tabBarConfig(.health)
            }
        } else {
            HomeView(path: $homePath)
        }
    }
    
    @ViewBuilder
    func exploreTabContent() -> some View {
        if tabBar.config == .dailyHabits {
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
    /// Proxy selection that maps to the native `.search` role tab.
    case searchProxy
}

// MARK: - Today Placeholder

private struct TodayPlaceholderView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.tertiary)
            Text("Today")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
            Text("Your daily overview is coming soon.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Preview

#Preview {
    MainContainerView()
        .environment(\.injected, .previewAuthenticated)
}
