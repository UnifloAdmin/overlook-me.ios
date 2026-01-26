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
            // Execute pending navigation after sheet is fully dismissed
            print("📋 Sheet dismissed. Pending navigation: \(String(describing: pendingNavigation))")
            
            guard let pendingRoute = pendingNavigation else {
                print("⚠️ No pending navigation, sheet was just closed")
                return
            }
            
            pendingNavigation = nil
            
            // Give the sheet animation time to fully complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                print("🚀 Executing navigation to: \(pendingRoute)")
                open(pendingRoute)
            }
        }) {
            SideNavigationView(
                isPresented: $showingSideNav,
                onSelectRoute: { route in
                    // Store the route - navigation will happen in onDismiss
                    print("✅ Route selected in callback: \(route)")
                    pendingNavigation = route
                }
            )
        }
        .onChange(of: selection) { oldValue, newValue in
            print("🔀 Selection changed: \(oldValue) → \(newValue)")
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
        .onChange(of: tabBar.config) { oldValue, newValue in
            // Prevent redundant updates if config hasn't actually changed
            guard oldValue != newValue else { return }
            
            print("⚙️ TabBar config changed: \(oldValue) → \(newValue)")
            
            // Clear navigation path when entering dailyHabits, tasks, health, bankAccounts, or transactions mode
            if newValue == .dailyHabits || newValue == .tasks || newValue == .health || newValue == .bankAccounts || newValue == .transactions {
                homePath = NavigationPath()
            }
            
            // Clear path when leaving dailyHabits, tasks, health, bankAccounts, or transactions mode
            if (oldValue == .dailyHabits || oldValue == .tasks || oldValue == .health || oldValue == .bankAccounts || oldValue == .transactions) && newValue != oldValue {
                homePath = NavigationPath()
                selection = .home
            }
            
            if newValue.messages == nil && selection == .messages {
                selection = .home
            }
        }
    }
    
    private func open(_ route: SideNavRoute) {
        print("🔄 open() called with route: \(route)")
        
        if route == .dailyHabits {
            // Switch the entire experience into the dedicated Daily Habits tab
            print("📱 Switching to Daily Habits mode")
            
            // Batch all state changes together to avoid multiple updates per frame
            let needsConfigChange = tabBar.config != .dailyHabits
            
            // Clear path first
            homePath = NavigationPath()
            
            // Then set selection if needed
            if selection != .home {
                selection = .home
            }
            
            // Finally update config if needed with a slight delay to avoid same-frame updates
            if needsConfigChange {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    var transaction = Transaction(animation: .easeInOut(duration: 0.35))
                    transaction.disablesAnimations = false
                    withTransaction(transaction) {
                        self.tabBar.config = .dailyHabits
                    }
                }
            }
            return
        }
        
        if route == .tasks {
            // Switch the entire experience into the dedicated Tasks tab
            print("📱 Switching to Tasks mode")
            
            // Batch all state changes together to avoid multiple updates per frame
            let needsConfigChange = tabBar.config != .tasks
            
            // Clear path first
            homePath = NavigationPath()
            
            // Then set selection if needed
            if selection != .home {
                selection = .home
            }
            
            // Finally update config if needed with a slight delay to avoid same-frame updates
            if needsConfigChange {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    var transaction = Transaction(animation: .easeInOut(duration: 0.35))
                    transaction.disablesAnimations = false
                    withTransaction(transaction) {
                        self.tabBar.config = .tasks
                    }
                }
            }
            return
        }
        
        if route == .healthDashboard || route == .healthInsights {
            // Switch the entire experience into the dedicated Health tab
            print("📱 Switching to Health mode")
            
            // Batch all state changes together to avoid multiple updates per frame
            let needsConfigChange = tabBar.config != .health
            
            // Clear path first
            homePath = NavigationPath()
            
            // Switch to the alerts tab (where health content is)
            if selection != .notifications {
                selection = .notifications
            }
            
            // Finally update config if needed with a slight delay to avoid same-frame updates
            if needsConfigChange {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    var transaction = Transaction(animation: .easeInOut(duration: 0.35))
                    transaction.disablesAnimations = false
                    withTransaction(transaction) {
                        self.tabBar.config = .health
                    }
                }
            }
            return
        }
        
        if route == .bankAccounts {
            // Switch the entire experience into the dedicated Bank Accounts mode
            print("📱 Switching to Bank Accounts mode")
            
            let needsConfigChange = tabBar.config != .bankAccounts
            
            homePath = NavigationPath()
            
            if selection != .home {
                selection = .home
            }
            
            if needsConfigChange {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    var transaction = Transaction(animation: .easeInOut(duration: 0.35))
                    transaction.disablesAnimations = false
                    withTransaction(transaction) {
                        self.tabBar.config = .bankAccounts
                    }
                }
            }
            return
        }
        
        if route == .transactions {
            // Switch the entire experience into the dedicated Transactions mode
            print("📱 Switching to Transactions mode")
            
            let needsConfigChange = tabBar.config != .transactions
            
            homePath = NavigationPath()
            
            if selection != .home {
                selection = .home
            }
            
            if needsConfigChange {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    var transaction = Transaction(animation: .easeInOut(duration: 0.35))
                    transaction.disablesAnimations = false
                    withTransaction(transaction) {
                        self.tabBar.config = .transactions
                    }
                }
            }
            return
        }
        
        print("📱 Navigating to: \(route)")
        
        // For other routes, ensure we're in default mode and coordinate navigation
        let needsConfigReset = tabBar.config == .dailyHabits || tabBar.config == .tasks || tabBar.config == .health || tabBar.config == .bankAccounts || tabBar.config == .transactions
        
        if needsConfigReset {
            // Reset from dailyHabits, tasks, or health mode
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                var transaction = Transaction(animation: .easeInOut(duration: 0.35))
                transaction.disablesAnimations = false
                withTransaction(transaction) {
                    self.tabBar.config = .default
                    self.selection = .home
                }
                
                // Add route to path after config change settles
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    self.homePath.append(route)
                }
            }
        } else {
            // Normal navigation
            if selection != .home {
                selection = .home
            }
            
            // Small delay to ensure tab selection completes before navigation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self.homePath.append(route)
            }
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
        } else {
            NavigationStack {
                FocusView()
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
        } else if tabBar.config == .health {
            NavigationStack {
                HealthInsightsView()
                    .tabBarConfig(.health)
            }
        } else if tabBar.config == .transactions {
            NavigationStack {
                TransactionsView(viewModel: transactionsViewModel, tab: .merchants)
            }
        } else {
            NavigationStack {
                HealthView()
                    .tabBarConfig(.health)
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

// MARK: - Placeholder View

// MARK: - Preview

#Preview {
    MainContainerView()
        .environment(\.injected, .previewAuthenticated)
}
