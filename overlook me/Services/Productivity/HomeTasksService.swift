import Foundation
import Combine

// MARK: - State

struct HomeTasksState {
    var analytics: TaskAnalyticsResponseDTO?
    var isLoading: Bool
    var failed: Bool

    static let loading = HomeTasksState(analytics: nil, isLoading: true, failed: false)

    // MARK: - Overview

    var totalTasks: Int     { overview?["totalTasks"]?.intValue ?? 0 }
    var completedTasks: Int { overview?["completedTasks"]?.intValue ?? 0 }
    var pendingTasks: Int   { overview?["pendingTasks"]?.intValue ?? 0 }
    var inProgress: Int     { overview?["inProgressTasks"]?.intValue ?? 0 }
    var overdueTasks: Int   { overview?["overdueTasks"]?.intValue ?? 0 }
    var completionRate: Int {
        let rate = overview?["completionRate"]?.doubleValue ?? 0
        return rate.isNaN ? 0 : Int(rate.rounded())
    }

    // MARK: - Time Analytics

    var dueToday: Int       { time?["dueToday"]?.intValue ?? 0 }
    var dueThisWeek: Int    { time?["dueThisWeek"]?.intValue ?? 0 }
    var completedToday: Int { time?["completedToday"]?.intValue ?? 0 }

    // MARK: - Headline

    var headline: String {
        if overdueTasks >= 3  { return "A few tasks need your attention — let's tackle them" }
        if overdueTasks > 0   { return "You have something overdue — a quick win is waiting" }
        if dueToday > 0 && completedToday == dueToday { return "Today's tasks are done — nicely handled!" }
        if dueToday > 2      { return "\(dueToday) tasks due today — pace yourself" }
        if dueToday > 0      { return "A manageable day ahead — you've got this" }
        if completionRate >= 80 { return "Strong momentum — keep it going" }
        if inProgress > 3    { return "A few things in motion — stay focused" }
        if totalTasks == 0   { return "Clean slate — ready when you are" }
        return "Things are looking good — steady progress"
    }

    // MARK: - Derived helpers

    private var overview: [String: JSONValue]? {
        analytics?["overview"]?.objectValue
    }

    private var time: [String: JSONValue]? {
        analytics?["timeAnalytics"]?.objectValue
    }
}

// MARK: - Service

@MainActor
final class HomeTasksService: ObservableObject {
    @Published private(set) var state: HomeTasksState = .loading

    private let tasksAPI = TasksAPI(client: LoggingAPIClient(base: AppAPIClient.live()))
    private var loadedUserId: String?

    func load(userId: String) async {
        guard userId != loadedUserId || state.failed else { return }
        loadedUserId = userId
        state = .loading

        do {
            let analytics = try await tasksAPI.getAnalytics(
                TaskAnalyticsRequestDTO(
                    userId: userId,
                    startDate: nil,
                    endDate: nil,
                    includeArchived: false,
                    project: nil,
                    category: nil
                )
            )
            state = HomeTasksState(analytics: analytics, isLoading: false, failed: false)
        } catch {
            state = HomeTasksState(analytics: nil, isLoading: false, failed: true)
        }
    }

    func refresh(userId: String) async {
        loadedUserId = nil
        await load(userId: userId)
    }
}
