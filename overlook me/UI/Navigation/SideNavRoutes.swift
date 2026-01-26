import SwiftUI

enum SideNavRoute: String, Hashable {
    case homeDashboard
    case weeklyInsights
    
    case financeDashboard
    case bankAccounts
    case trends
    case transactions
    case budgets
    case insights
    case netWorth
    
    case productivityDashboard
    case tasks
    case dailyHabits
    
    case healthDashboard
    case healthInsights
    case fitness
    
    case mySubscriptions
    case managePlan
    case notificationManage
    case friendCircle
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
        id: "dashboards",
        label: "Dashboards",
        color: Color(hex: "#ff7043"),
        items: [
            .init(route: .homeDashboard, label: "Home", systemImage: "house"),
            .init(route: .weeklyInsights, label: "Weekly Insights", systemImage: "calendar.badge.clock")
        ]
    ),
    .init(
        id: "finance",
        label: "Finance",
        color: .green,
        items: [
            .init(route: .bankAccounts, label: "Bank Accounts", systemImage: "building.columns.fill"),
            .init(route: .transactions, label: "Transactions", systemImage: "arrow.left.arrow.right"),
            .init(route: .budgets, label: "Budgets", systemImage: "wallet.pass.fill"),
            .init(route: .mySubscriptions, label: "Recurring Payments", systemImage: "arrow.clockwise.circle.fill"),
            .init(route: .insights, label: "Insights", systemImage: "chart.bar.xaxis")
        ]
    ),
    .init(
        id: "productivity",
        label: "Productivity",
        color: .blue,
        items: [
            .init(route: .tasks, label: "Tasks", systemImage: "square.and.pencil"),
            .init(route: .dailyHabits, label: "Habit Tracker", systemImage: "repeat.circle.fill")
        ]
    ),
    .init(
        id: "health",
        label: "Health",
        color: .pink,
        items: [
            .init(route: .healthInsights, label: "Insights", systemImage: "chart.line.uptrend.xyaxis"),
            .init(route: .fitness, label: "Fitness", systemImage: "figure.run")
        ]
    ),
    .init(
        id: "controllers",
        label: "Controllers",
        color: Color(hex: "#3949ab"),
        items: [
            .init(route: .managePlan, label: "Manage Plan", systemImage: "star.circle.fill"),
            .init(route: .notificationManage, label: "Notifications", systemImage: "bell.badge"),
            .init(route: .friendCircle, label: "My Friend Circle", systemImage: "person.2.circle")
        ]
    )
]

