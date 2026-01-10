import SwiftUI

enum SideNavRoute: String, Hashable {
    case homeDashboard
    
    case financeDashboard
    case bankAccounts
    case transactions
    case budgets
    case insights
    case netWorth
    
    case productivityDashboard
    case tasks
    case dailyHabits
    case checklists
    
    case managePlan
}

struct SideNavItem: Identifiable {
    let route: SideNavRoute
    let label: String
    let systemImage: String
    
    var id: String { route.rawValue }
}

struct SideNavSection: Identifiable {
    let id: String
    let label: String
    let color: Color
    let items: [SideNavItem]
}

let SIDE_NAV_SECTIONS: [SideNavSection] = [
    .init(
        id: "home",
        label: "Home",
        color: Color(hex: "#ff7043"),
        items: [
            .init(route: .homeDashboard, label: "Dashboard", systemImage: "rectangle.grid.2x2")
        ]
    ),
    .init(
        id: "finance",
        label: "Finance",
        color: .green,
        items: [
            .init(route: .financeDashboard, label: "Finance Dashboard", systemImage: "chart.line.uptrend.xyaxis"),
            .init(route: .bankAccounts, label: "Bank Accounts", systemImage: "building.columns"),
            .init(route: .transactions, label: "Transactions", systemImage: "arrow.left.arrow.right"),
            .init(route: .budgets, label: "Budgets", systemImage: "wallet.bifold"),
            .init(route: .insights, label: "Insights", systemImage: "sparkles"),
            .init(route: .netWorth, label: "Net Worth", systemImage: "chart.line.uptrend.xyaxis.circle")
        ]
    ),
    .init(
        id: "productivity",
        label: "Productivity",
        color: .blue,
        items: [
            .init(route: .productivityDashboard, label: "Productivity Dashboard", systemImage: "square.grid.2x2"),
            .init(route: .tasks, label: "Tasks", systemImage: "checklist"),
            .init(route: .dailyHabits, label: "Daily Habits", systemImage: "checkmark.circle"),
            .init(route: .checklists, label: "Checklists", systemImage: "list.bullet.rectangle")
        ]
    ),
    .init(
        id: "subscriptions",
        label: "Subscriptions",
        color: Color(hex: "#3949ab"),
        items: [
            .init(route: .managePlan, label: "Manage Plan", systemImage: "crown")
        ]
    )
]

