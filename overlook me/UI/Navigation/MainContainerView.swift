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
                NavigationStack(path: $homePath) {
                    HomeView()
                        .tabBarConfig(.default)
                        .navigationDestination(for: SideNavRoute.self) { route in
                            destination(for: route)
                        }
                }
                .environmentObject(tabBar)
            }
            
            Tab(tabBar.config.explore.title, systemImage: tabBar.config.explore.systemImage, value: .explore) {
                NavigationStack {
                    PlaceholderView(
                        title: "Explore",
                        icon: "safari.fill",
                        description: "Discover new content and explore features"
                    )
                    .tabBarConfig(.default)
                }
                .environmentObject(tabBar)
            }
            
            Tab(tabBar.config.alerts.title, systemImage: tabBar.config.alerts.systemImage, value: .notifications) {
                NavigationStack {
                    PlaceholderView(
                        title: "Notifications",
                        icon: "bell.fill",
                        description: "Stay updated with your latest alerts"
                    )
                    .tabBarConfig(.default)
                }
                .environmentObject(tabBar)
            }
            
            Tab(tabBar.config.messages.title, systemImage: tabBar.config.messages.systemImage, value: .messages) {
                NavigationStack {
                    PlaceholderView(
                        title: "Messages",
                        icon: "envelope.fill",
                        description: "View and manage your messages"
                    )
                    .tabBarConfig(.default)
                }
                .environmentObject(tabBar)
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
            }
        }
    }
    
    private func open(_ route: SideNavRoute) {
        // For now, all side-nav routes push on the Home tab stack.
        selection = .home
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
                .tabBarConfig(.productivity)
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
