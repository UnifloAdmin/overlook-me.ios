import Foundation
import Combine

// MARK: - State

struct HomeHabitsState {
    var habits: [DailyHabitDTO]
    var analytics: HabitAnalyticsDTO?
    var isLoading: Bool
    var failed: Bool

    static let loading = HomeHabitsState(habits: [], analytics: nil, isLoading: true, failed: false)

    var todayCount: Int { habits.count }

    var todayCompleted: Int {
        let todayStr = ISO8601DateFormatter.dateOnly.string(from: Date())
        return habits.filter { habit in
            habit.completionLogs?.contains { log in
                String(log.date.prefix(10)) == todayStr && log.completed
            } ?? false
        }.count
    }

    var todayPct: Int {
        guard todayCount > 0 else { return 0 }
        return Int((Double(todayCompleted) / Double(todayCount) * 100).rounded())
    }

    var activeHabits: Int {
        analyticsObj?["activeHabits"]?.intValue ?? 0
    }

    var overallRate: Int {
        let rate = analyticsObj?["overallCompletionRate"]?.doubleValue ?? 0
        return rate.isNaN ? 0 : Int(rate.rounded())
    }

    var currentStreaks: Int {
        analyticsObj?["currentStreaks"]?.intValue ?? 0
    }

    var weeklyProgress: [(day: String, rate: Int)] {
        guard let arr = analyticsObj?["weeklyProgress"]?.arrayValue else { return [] }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        let dayFmt = DateFormatter()
        dayFmt.dateFormat = "E"

        return arr.suffix(7).compactMap { entry in
            guard let dateStr = entry["date"]?.stringValue,
                  let rate = entry["completionRate"]?.doubleValue else { return nil }
            let label: String
            if let d = fmt.date(from: String(dateStr.prefix(19))) {
                label = String(dayFmt.string(from: d).prefix(1))
            } else {
                label = "?"
            }
            return (day: label, rate: Int(rate.rounded()))
        }
    }

    private var analyticsObj: [String: JSONValue]? {
        guard let a = analytics else { return nil }
        // HabitAnalyticsDTO is [String: JSONValue], so it's already a dict
        return a
    }

    var headline: String {
        let pct    = todayPct
        let total  = todayCount
        let done   = todayCompleted
        let streak = currentStreaks
        if total == 0         { return "No habits scheduled today — rest day?" }
        if pct == 100         { return "All done for today — you crushed it!" }
        if pct >= 75          { return "Almost there — just a few more to go" }
        if done == 0 && streak > 3 { return "Don't break your \(streak)-day streak — get started" }
        if done == 0          { return "Fresh start — your habits are waiting for you" }
        if pct >= 50          { return "Halfway through — keep the momentum going" }
        return "\(total - done) habits left — you've got this"
    }

    var streakMessage: String {
        let s = currentStreaks
        if s >= 30 { return "Incredible consistency" }
        if s >= 14 { return "On a great run" }
        if s >= 7  { return "Solid week" }
        if s >= 3  { return "Building momentum" }
        if s >= 1  { return "Just getting started" }
        return "Start a streak today"
    }
}

// MARK: - ISO helper

private extension ISO8601DateFormatter {
    static let dateOnly: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()
}

// MARK: - Service

@MainActor
final class HomeHabitsService: ObservableObject {
    @Published private(set) var state: HomeHabitsState = .loading

    private let habitsAPI = DailyHabitsAPI(client: LoggingAPIClient(base: AppAPIClient.live()))
    private var loadedUserId: String?

    func load(userId: String) async {
        guard userId != loadedUserId || state.failed else { return }
        loadedUserId = userId
        state = .loading

        let todayStr = ISO8601DateFormatter.dateOnly.string(from: Date())

        async let habitsCall    = habitsAPI.getHabits(userId: userId, isActive: true, isArchived: false, date: todayStr)
        async let analyticsCall = habitsAPI.getAnalytics(userId: userId)

        do {
            let (habits, analytics) = try await (habitsCall, analyticsCall)
            state = HomeHabitsState(habits: habits, analytics: analytics, isLoading: false, failed: false)
        } catch {
            state = HomeHabitsState(habits: [], analytics: nil, isLoading: false, failed: true)
        }
    }

    func refresh(userId: String) async {
        loadedUserId = nil
        await load(userId: userId)
    }
}
