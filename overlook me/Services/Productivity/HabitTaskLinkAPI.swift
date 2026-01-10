import Foundation

struct HabitTaskLinkAPI: Sendable {
    let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }
}

struct LinkHabitToTaskOptionsDTO: Codable, Sendable {
    let notes: String?
    let sortOrder: Int?
    let autoCheckInHabit: Bool?
    let expectedCompletionMinutes: Int?
}

struct LinkResponseDTO: Codable, Sendable {
    let message: String
}

extension HabitTaskLinkAPI {
    /// POST `/DailyHabits/{habitId}/tasks/{taskId}?userId=...&oauthId=...`
    func linkHabitToTask(
        habitId: String,
        taskId: String,
        userId: String,
        options: LinkHabitToTaskOptionsDTO? = nil,
        oauthId: String? = nil
    ) async throws -> LinkResponseDTO {
        try await client.request(
            .post,
            path: "DailyHabits/\(habitId)/tasks/\(taskId)",
            query: ["userId": userId, "oauthId": oauthId],
            headers: [:],
            body: options ?? JSONValue.object([:])
        )
    }

    /// DELETE `/DailyHabits/{habitId}/tasks/{taskId}?userId=...&oauthId=...`
    func unlinkHabitFromTask(habitId: String, taskId: String, userId: String, oauthId: String? = nil) async throws -> LinkResponseDTO {
        try await client.request(
            .delete,
            path: "DailyHabits/\(habitId)/tasks/\(taskId)",
            query: ["userId": userId, "oauthId": oauthId],
            headers: [:],
            body: nil
        )
    }

    /// GET `/DailyHabits/{habitId}/tasks?userId=...&includeInactive=...&oauthId=...`
    func getHabitLinkedTasks(habitId: String, userId: String, includeInactive: Bool = false, oauthId: String? = nil) async throws -> [TaskDTO] {
        try await client.request(
            .get,
            path: "DailyHabits/\(habitId)/tasks",
            query: ["userId": userId, "includeInactive": String(includeInactive), "oauthId": oauthId],
            headers: [:],
            body: nil
        )
    }

    /// GET `/Tasks/{taskId}/habits?userId=...&includeInactive=...`
    func getTaskLinkedHabits(taskId: String, userId: String, includeInactive: Bool = false) async throws -> [DailyHabitDTO] {
        try await client.request(
            .get,
            path: "Tasks/\(taskId)/habits",
            query: ["userId": userId, "includeInactive": String(includeInactive)],
            headers: [:],
            body: nil
        )
    }
}

