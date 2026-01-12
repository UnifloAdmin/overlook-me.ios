import SwiftUI
import Combine

struct TabItemStyle: Equatable {
    var title: String
    var systemImage: String
}

struct TabBarConfiguration: Equatable {
    var home: TabItemStyle
    var explore: TabItemStyle
    var alerts: TabItemStyle
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
    
    static let subscriptions = TabBarConfiguration(
        home: .init(title: "Home", systemImage: "house.fill"),
        explore: .init(title: "Plans", systemImage: "crown"),
        alerts: .init(title: "Alerts", systemImage: "bell.fill"),
        messages: .init(title: "Support", systemImage: "questionmark.circle")
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

