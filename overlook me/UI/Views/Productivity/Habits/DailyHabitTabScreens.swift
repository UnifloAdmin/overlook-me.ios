import SwiftUI

/// Placeholder shells for the dedicated Daily Habits tab variants.
struct HabitsTabRootView: View {
    var body: some View {
        DailyHabitsView()
    }
}

struct ChallengesTabView: View {
    var body: some View {
        ChallengesDashboardView()
    }
}

struct AnalyticsTabView: View {
    var body: some View {
        HabitsAnalyticsView()
    }
}

struct AddNewHabitTabView: View {
    var body: some View {
        AddNewHabitView()
    }
}
