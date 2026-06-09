import SwiftUI

enum SideNavRoute: String, Hashable {
    case homeDashboard
    case weeklyInsights

    case financeDashboard
    case bankAccounts
    case trends
    case transactions
    case spending
    case budgets
    case insights
    case netWorth

    case productivityDashboard
    case tasks
    case dailyHabits
    case dSprints
    case waterTracker
    case reminders

    case healthDashboard
    case healthInsights
    case fitness
    case healthSleep
    case healthHeart
    case healthMobility
    case healthRespiration
    case healthFitness
    case healthExercise
    case quitVape

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
    let items: [SideNavItem]
}

let SIDE_NAV_SECTIONS: [SideNavSection] = [
    .init(id: "home", label: "Home", items: [
        .init(route: .homeDashboard, label: "Home", systemImage: "house.fill")
    ]),
    .init(id: "finance", label: "Finance", items: [
        .init(route: .bankAccounts,    label: "Bank Accounts",      systemImage: "building.columns.fill"),
        .init(route: .transactions,    label: "Transactions",        systemImage: "arrow.left.arrow.right"),
        .init(route: .spending,        label: "Spending",            systemImage: "creditcard.fill"),
        .init(route: .budgets,         label: "Budgets",             systemImage: "wallet.pass.fill"),
        .init(route: .mySubscriptions, label: "Recurring Payments",  systemImage: "arrow.clockwise.circle.fill"),
        .init(route: .insights,        label: "Insights",            systemImage: "chart.bar.xaxis")
    ]),
    .init(id: "productivity", label: "Productivity", items: [
        .init(route: .tasks,       label: "Tasks",         systemImage: "square.and.pencil"),
        .init(route: .dailyHabits, label: "Habit Tracker", systemImage: "repeat.circle.fill"),
        .init(route: .dSprints,    label: "D-Sprints",     systemImage: "clock.badge.checkmark.fill"),
        .init(route: .waterTracker,label: "Water",         systemImage: "drop.fill"),
        .init(route: .reminders,   label: "Reminders",     systemImage: "bell.fill")
    ]),
    .init(id: "health", label: "Health", items: [
        .init(route: .healthInsights,   label: "Insights",    systemImage: "chart.line.uptrend.xyaxis"),
        .init(route: .healthSleep,      label: "Sleep",       systemImage: "moon.stars.fill"),
        .init(route: .healthHeart,      label: "Heart",       systemImage: "heart.fill"),
        .init(route: .healthMobility,   label: "Mobility",    systemImage: "figure.walk"),
        .init(route: .healthRespiration,label: "Respiration", systemImage: "lungs.fill"),
        .init(route: .healthFitness,    label: "Fitness",     systemImage: "figure.run"),
        .init(route: .healthExercise,   label: "Exercise",    systemImage: "dumbbell.fill"),
        .init(route: .quitVape,         label: "Quit Vape",   systemImage: "lungs.fill")
    ]),
    .init(id: "controllers", label: "Controllers", items: [
        .init(route: .managePlan,        label: "Manage Plan",      systemImage: "star.circle.fill"),
        .init(route: .notificationManage,label: "Notifications",    systemImage: "bell.badge"),
        .init(route: .friendCircle,      label: "My Friend Circle", systemImage: "person.2.circle")
    ])
]
