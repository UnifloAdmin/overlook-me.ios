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
    
    case mySubscriptions
    case managePlan
    case notificationManage
    case friendCircle
}

struct SideNavItem: Identifiable {
    let route: SideNavRoute
    let label: String
    let systemImage: String
    let gradientTop: Color
    let gradientBottom: Color
    
    var id: String { route.rawValue }
}

struct SideNavSection: Identifiable {
    let id: String
    let label: String
    let color: Color
    let gradientTop: Color
    let gradientBottom: Color
    let heroIcon: String
    let items: [SideNavItem]
}

let SIDE_NAV_SECTIONS: [SideNavSection] = [
    .init(
        id: "dashboards",
        label: "Home",
        color: Color(hex: "#ff7043"),
        gradientTop: Color(hex: "#ff7043"),
        gradientBottom: Color(hex: "#d84315"),
        heroIcon: "house.fill",
        items: [
            .init(route: .homeDashboard, label: "Home", systemImage: "house.fill",
                  gradientTop: Color(hex: "#ff7043"), gradientBottom: Color(hex: "#bf360c"))
        ]
    ),
    .init(
        id: "finance",
        label: "Finance",
        color: .green,
        gradientTop: Color(hex: "#43a047"),
        gradientBottom: Color(hex: "#1b5e20"),
        heroIcon: "building.columns.fill",
        items: [
            .init(route: .bankAccounts, label: "Bank Accounts", systemImage: "building.columns.fill",
                  gradientTop: Color(hex: "#26a69a"), gradientBottom: Color(hex: "#00695c")),
            .init(route: .transactions, label: "Transactions", systemImage: "arrow.left.arrow.right",
                  gradientTop: Color(hex: "#42a5f5"), gradientBottom: Color(hex: "#1565c0")),
            .init(route: .spending, label: "Spending", systemImage: "creditcard.fill",
                  gradientTop: Color(hex: "#ef5350"), gradientBottom: Color(hex: "#b71c1c")),
            .init(route: .budgets, label: "Budgets", systemImage: "wallet.pass.fill",
                  gradientTop: Color(hex: "#66bb6a"), gradientBottom: Color(hex: "#2e7d32")),
            .init(route: .mySubscriptions, label: "Recurring Payments", systemImage: "arrow.clockwise.circle.fill",
                  gradientTop: Color(hex: "#ffa726"), gradientBottom: Color(hex: "#e65100")),
            .init(route: .insights, label: "Insights", systemImage: "chart.bar.xaxis",
                  gradientTop: Color(hex: "#5c6bc0"), gradientBottom: Color(hex: "#283593"))
        ]
    ),
    .init(
        id: "productivity",
        label: "Productivity",
        color: .blue,
        gradientTop: Color(hex: "#7c4dff"),
        gradientBottom: Color(hex: "#4a148c"),
        heroIcon: "square.and.pencil",
        items: [
            .init(route: .tasks, label: "Tasks", systemImage: "square.and.pencil",
                  gradientTop: Color(hex: "#7e57c2"), gradientBottom: Color(hex: "#4527a0")),
            .init(route: .dailyHabits, label: "Habit Tracker", systemImage: "repeat.circle.fill",
                  gradientTop: Color(hex: "#ab47bc"), gradientBottom: Color(hex: "#6a1b9a")),
            .init(route: .waterTracker, label: "Water", systemImage: "drop.fill",
                  gradientTop: Color(hex: "#29b6f6"), gradientBottom: Color(hex: "#0277bd")),
            .init(route: .reminders, label: "Reminders", systemImage: "bell.fill",
                  gradientTop: Color(hex: "#ffca28"), gradientBottom: Color(hex: "#f57f17"))
        ]
    ),
    .init(
        id: "health",
        label: "Health",
        color: .pink,
        gradientTop: Color(hex: "#e91e63"),
        gradientBottom: Color(hex: "#880e4f"),
        heroIcon: "heart.fill",
        items: [
            .init(route: .healthInsights, label: "Insights", systemImage: "chart.line.uptrend.xyaxis",
                  gradientTop: Color(hex: "#ec407a"), gradientBottom: Color(hex: "#ad1457")),
            .init(route: .healthSleep, label: "Sleep", systemImage: "moon.stars.fill",
                  gradientTop: Color(hex: "#5c6bc0"), gradientBottom: Color(hex: "#1a237e")),
            .init(route: .healthHeart, label: "Heart", systemImage: "heart.fill",
                  gradientTop: Color(hex: "#ef5350"), gradientBottom: Color(hex: "#c62828")),
            .init(route: .healthMobility, label: "Mobility", systemImage: "figure.walk",
                  gradientTop: Color(hex: "#66bb6a"), gradientBottom: Color(hex: "#1b5e20")),
            .init(route: .healthRespiration, label: "Respiration", systemImage: "lungs.fill",
                  gradientTop: Color(hex: "#26c6da"), gradientBottom: Color(hex: "#00838f")),
            .init(route: .healthFitness, label: "Fitness", systemImage: "figure.run",
                  gradientTop: Color(hex: "#ffa726"), gradientBottom: Color(hex: "#e65100")),
            .init(route: .healthExercise, label: "Exercise", systemImage: "dumbbell.fill",
                  gradientTop: Color(hex: "#8d6e63"), gradientBottom: Color(hex: "#4e342e"))
        ]
    ),
    .init(
        id: "controllers",
        label: "Controllers",
        color: Color(hex: "#3949ab"),
        gradientTop: Color(hex: "#5c6bc0"),
        gradientBottom: Color(hex: "#1a237e"),
        heroIcon: "gearshape.2.fill",
        items: [
            .init(route: .managePlan, label: "Manage Plan", systemImage: "star.circle.fill",
                  gradientTop: Color(hex: "#ffb300"), gradientBottom: Color(hex: "#ff6f00")),
            .init(route: .notificationManage, label: "Notifications", systemImage: "bell.badge",
                  gradientTop: Color(hex: "#7e57c2"), gradientBottom: Color(hex: "#311b92")),
            .init(route: .friendCircle, label: "My Friend Circle", systemImage: "person.2.circle",
                  gradientTop: Color(hex: "#26a69a"), gradientBottom: Color(hex: "#004d40"))
        ]
    )
]
