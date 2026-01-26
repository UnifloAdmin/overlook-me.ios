import SwiftUI
import Combine

struct TabItemStyle: Equatable {
    var title: String
    var systemImage: String
}

struct TabBarConfiguration: Equatable {
    var home: TabItemStyle
    var explore: TabItemStyle
    var alerts: TabItemStyle?
    var messages: TabItemStyle?
    var preserveTrailingSlot: Bool = false
    
    static let `default` = TabBarConfiguration(
        home: .init(title: "home", systemImage: "house.fill"),
        explore: .init(title: "Focus", systemImage: "safari.fill"),
        alerts: .init(title: "health", systemImage: "bell.fill"),
        messages: .init(title: "finances", systemImage: "dollarsign.circle.fill")
    )
    
    static let finance = TabBarConfiguration(
        home: .init(title: "Home", systemImage: "house.fill"),
        explore: .init(title: "Accounts", systemImage: "building.columns"),
        alerts: .init(title: "Insights", systemImage: "sparkles"),
        messages: .init(title: "Budgets", systemImage: "wallet.bifold")
    )
    
    static let productivity = TabBarConfiguration(
        home: .init(title: "Home", systemImage: "house.fill"),
        explore: .init(title: "Tasks", systemImage: "checklist"),
        alerts: .init(title: "Habits", systemImage: "checkmark.circle"),
        messages: .init(title: "Lists", systemImage: "list.bullet.rectangle")
    )
    
    static let dailyHabits = TabBarConfiguration(
        home: .init(title: "Habits", systemImage: "checkmark.circle.fill"),
        explore: .init(title: "Challenges", systemImage: "flag.2.crossed"),
        alerts: .init(title: "Analytics", systemImage: "chart.bar.xaxis"),
        messages: nil,
     
    )
    
    static let tasks = TabBarConfiguration(
        home: .init(title: "All Tasks", systemImage: "checklist"),
        explore: .init(title: "Backlogs", systemImage: "tray.full"),
        alerts: .init(title: "Analytics", systemImage: "chart.bar.xaxis"),
        messages: nil
    )
    
    static let bankAccounts = TabBarConfiguration(
        home: .init(title: "Accounts", systemImage: "building.columns.fill"),
        explore: .init(title: "Trends", systemImage: "chart.line.uptrend.xyaxis"),
        alerts: nil,
        messages: nil
    )
    
    static let transactions = TabBarConfiguration(
        home: .init(title: "Analytics", systemImage: "chart.bar.xaxis"),
        explore: .init(title: "Ledger", systemImage: "list.bullet.rectangle"),
        alerts: .init(title: "Merchants", systemImage: "storefront"),
        messages: nil
    )
    
    static let subscriptions = TabBarConfiguration(
        home: .init(title: "Home", systemImage: "house.fill"),
        explore: .init(title: "Plans", systemImage: "crown"),
        alerts: .init(title: "Alerts", systemImage: "bell.fill"),
        messages: .init(title: "Support", systemImage: "questionmark.circle")
    )
    
    static let health = TabBarConfiguration(
        home: .init(title: "Insights", systemImage: "chart.line.uptrend.xyaxis"),
        explore: .init(title: "Sleep", systemImage: "bed.double.fill"),
        alerts: .init(title: "Fitness", systemImage: "figure.run"),
        messages: .init(title: "Heart", systemImage: "heart.fill")
    )
}

final class TabBarStyleStore: ObservableObject {
    @Published var config: TabBarConfiguration = .default
}

private struct TabBarConfigModifier: ViewModifier {
    @EnvironmentObject private var tabBar: TabBarStyleStore
    let config: TabBarConfiguration
    
    func body(content: Content) -> some View {
        content
            .onAppear { tabBar.config = config }
    }
}

extension View {
    func tabBarConfig(_ config: TabBarConfiguration) -> some View {
        modifier(TabBarConfigModifier(config: config))
    }
}

