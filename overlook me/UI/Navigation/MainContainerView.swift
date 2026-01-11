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
    
    // Keep navigation *inside* tabs so the tab bar stays visible.
    @State private var homePath = NavigationPath()
    
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
            
            Tab(tabBar.config.alerts.title, systemImage: tabBar.config.alerts.systemImage, value: .notifications) {
                alertsTabContent()
                    .environmentObject(tabBar)
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
        .tabBarMinimizeBehavior(.onScrollDown)
        .sheet(isPresented: $showingSideNav) {
            SideNavigationView(
                isPresented: $showingSideNav,
                onSelectRoute: { route in
                    open(route)
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
        }
        .onChange(of: tabBar.config) { oldValue, newValue in
            if newValue == .dailyHabits {
                homePath = NavigationPath()
            }
            
            if oldValue == .dailyHabits && newValue != .dailyHabits {
                selection = .home
            }
            
            if newValue.messages == nil && selection == .messages {
                selection = .home
            }
        }
    }
    
    private func open(_ route: SideNavRoute) {
        // All routes start on the Home tab.
        selection = .home
        
        if route == .dailyHabits {
            // Switch the entire experience into the dedicated Daily Habits tab
            // instead of stacking another instance that immediately gets popped.
            homePath = NavigationPath()
            if tabBar.config != .dailyHabits {
                tabBar.config = .dailyHabits
            }
            return
        }
        
        DispatchQueue.main.async {
            homePath.append(route)
        }
    }
    
    @ViewBuilder
    private func destination(for route: SideNavRoute) -> some View {
        switch route {
        case .homeDashboard:
            HomeDashboardView()
                .tabBarConfig(.default)
            
        case .financeDashboard:
            FinanceDashboardView()
                .tabBarConfig(.finance)
        case .bankAccounts:
            BankAccountsView()
                .tabBarConfig(.finance)
        case .transactions:
            TransactionsView()
                .tabBarConfig(.finance)
        case .budgets:
            BudgetsView()
                .tabBarConfig(.finance)
        case .insights:
            InsightsView()
                .tabBarConfig(.finance)
        case .netWorth:
            NetWorthView()
                .tabBarConfig(.finance)
            
        case .productivityDashboard:
            ProductivityDashboardView()
                .tabBarConfig(.productivity)
        case .tasks:
            TasksView()
                .tabBarConfig(.productivity)
        case .dailyHabits:
            DailyHabitsView()
                .tabBarConfig(.dailyHabits)
        case .checklists:
            ChecklistsView()
                .tabBarConfig(.productivity)
            
        case .managePlan:
            ManagePlanView()
                .tabBarConfig(.subscriptions)
        }
    }
}

// MARK: - Tab Selection

private extension MainContainerView {
    @ViewBuilder
    func homeTabContent() -> some View {
        NavigationStack(path: $homePath) {
            homeRootView()
                .navigationDestination(for: SideNavRoute.self) { route in
                    destination(for: route)
                }
        }
    }
    
    @ViewBuilder
    private func homeRootView() -> some View {
        if tabBar.config == .dailyHabits {
            DailyHabitsView()
                .tabBarConfig(.dailyHabits)
        } else {
            HomeDashboardView()
                .tabBarConfig(.default)
        }
    }
    
    @ViewBuilder
    func exploreTabContent() -> some View {
        if tabBar.config == .dailyHabits {
            NavigationStack {
                ChallengesTabView()
                    .tabBarConfig(.dailyHabits)
            }
        } else {
            NavigationStack {
                PlaceholderView(
                    title: "Explore",
                    icon: "safari.fill",
                    description: "Discover new content and explore features"
                )
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
        } else {
            NavigationStack {
                PlaceholderView(
                    title: "Notifications",
                    icon: "bell.fill",
                    description: "Stay updated with your latest alerts"
                )
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
                PlaceholderView(
                    title: "Messages",
                    icon: "envelope.fill",
                    description: "View and manage your messages"
                )
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

// MARK: - Placeholder View

private struct PlaceholderView: View {
    let title: String
    let icon: String
    let description: String
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: icon)
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text(title)
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text(description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview {
    MainContainerView()
        .environment(\.injected, .previewAuthenticated)
}
