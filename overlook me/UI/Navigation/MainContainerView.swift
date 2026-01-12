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
        .tabBarMinimizeBehavior(.never)
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
    func homeTabContent() -> some View {
        HomeView(path: $homePath)
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
        } else {
            NavigationStack {
                HealthView()
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

// MARK: - Placeholder View

// MARK: - Preview

#Preview {
    MainContainerView()
        .environment(\.injected, .previewAuthenticated)
}
