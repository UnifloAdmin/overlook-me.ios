import Foundation

struct DailyHabitsAPI: Sendable {
    let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }
}

struct DailyHabitDTO: Codable, Sendable, Identifiable {
    let id: String
    let userId: String
    let oauthId: String?

    let name: String
    let description: String?
    let category: String?
    let color: String?
    let icon: String?

    let frequency: String?
    let targetDays: [String]?
    let isIndefinite: Bool?
    let remindersEnabled: Bool?
    let priority: String?
    let isPinned: Bool?
    let isPositive: Bool?
    let sortOrder: Int?
    let tags: String?

    let isActive: Bool?
    let isArchived: Bool?

    let currentStreak: Int?
    let longestStreak: Int?
    let totalCompletions: Int?
    let completionRate: Double?
    let completionLogs: [HabitCompletionLogDTO]?

    let createdAt: String?
    let updatedAt: String?
}

struct CreateDailyHabitRequestDTO: Codable, Sendable {
    let name: String
    let description: String?
    let category: String?
    let color: String?
    let icon: String?
    let frequency: String?
    let targetDays: [String]?
    let dailyGoal: String?
    let goalType: String?
    let targetValue: Double?
    let unit: String?
    let preferredTime: String?
    let scheduledTime: String?
    let startDate: String?
    let endDate: String?
    let expiryDate: String?
    let isIndefinite: Bool?
    let remindersEnabled: Bool?
    let priority: String?
    let isPinned: Bool?
    let isPositive: Bool?
    let tags: String?
    let motivation: String?
    let reward: String?
    let timeZone: String?
}

struct UpdateDailyHabitRequestDTO: Codable, Sendable {
    let id: String
    let name: String?
    let description: String?
    let category: String?
    let color: String?
    let icon: String?
    let frequency: String?
    let targetDays: [String]?
    let dailyGoal: String?
    let goalType: String?
    let targetValue: Double?
    let unit: String?
    let preferredTime: String?
    let scheduledTime: String?
    let isActive: Bool?
    let endDate: String?
    let expiryDate: String?
    let isIndefinite: Bool?
    let remindersEnabled: Bool?
    let priority: String?
    let isPinned: Bool?
    let isPositive: Bool?
    let sortOrder: Int?
    let tags: String?
    let motivation: String?
    let reward: String?
    let timeZone: String?
}

struct EffortMetricDTO: Codable, Sendable {
    let metricType: String
    let metricValue: Double
    let metricUnit: String
    let displayLabel: String?
}

struct CompletionReasonDTO: Codable, Sendable {
    let reasonType: String
    let reasonText: String
    let triggerCategory: String?
    let sentiment: String?
}

struct LogHabitCompletionRequestDTO: Codable, Sendable {
    let habitId: String
    let date: String
    let completed: Bool
    let value: Double?
    let notes: String?
    let wasSkipped: Bool?
    let completedAt: String?
    let metrics: [EffortMetricDTO]?
    let reason: CompletionReasonDTO?
    let generalNotes: String?
}

struct HabitCompletionLogDTO: Codable, Sendable {
    let date: String
    let completed: Bool
    let value: Double?
    let notes: String?
    let completedAt: String?
    let wasSkipped: Bool?
}

/// Full log entry returned by `GET /dailyhabits/{habitId}/logs`.
struct HabitCompletionLogEntryDTO: Codable, Sendable, Identifiable {
    let id: String
    let habitId: String
    let habitName: String?
    let date: String
    let completed: Bool
    let wasSkipped: Bool?
    let generalNotes: String?
    let metrics: [EffortMetricDTO]?
    let reason: CompletionReasonDTO?
    let completedAt: String?
    let createdAt: String?
    let updatedAt: String?
}

struct CheckInHabitRequestDTO: Codable, Sendable {
    let value: Double?
    let notes: String?
}

struct CheckInHabitResponseDTO: Codable, Sendable {
    let message: String
    let habit: DailyHabitDTO
}

struct HabitStreakDTO: Codable, Sendable {
    let habitId: String
    let habitName: String
    let currentStreak: Int
    let longestStreak: Int
    let totalCompletions: Int
    let completionRate: Double
}

typealias HabitAnalyticsDTO = [String: JSONValue]

extension DailyHabitsAPI {
    /// GET `/dailyhabits`
    func getHabits(
        userId: String? = nil,
        oauthId: String? = nil,
        habitId: String? = nil,
        category: String? = nil,
        priority: String? = nil,
        isPinned: Bool? = nil,
        isActive: Bool? = nil,
        isArchived: Bool? = nil,
        date: String? = nil
    ) async throws -> [DailyHabitDTO] {
        try await client.request(
            .get,
            path: "dailyhabits",
            query: [
                "userId": userId,
                "oauthId": oauthId,
                "habitId": habitId,
                "category": category,
                "priority": priority,
                "isPinned": isPinned.map(String.init),
                "isActive": isActive.map(String.init),
                "isArchived": isArchived.map(String.init),
                "date": date
            ],
            headers: [:],
            body: nil
        )
    }

    /// GET `/dailyhabits` but returns a single object when `habitId` is provided (matches web client behavior).
    func getHabitById(habitId: String, userId: String, oauthId: String? = nil) async throws -> DailyHabitDTO {
        try await client.request(
            .get,
            path: "dailyhabits",
            query: [
                "userId": userId,
                "habitId": habitId,
                "oauthId": oauthId
            ],
            headers: [:],
            body: nil
        )
    }

    /// POST `/dailyhabits?userId=...&oauthId=...`
    func createHabit(userId: String, habit: CreateDailyHabitRequestDTO, oauthId: String? = nil) async throws -> DailyHabitDTO {
        struct Response: Codable { let message: String?; let habit: DailyHabitDTO }
        let response: Response = try await client.request(
            .post,
            path: "dailyhabits",
            query: ["userId": userId, "oauthId": oauthId],
            headers: [:],
            body: habit
        )
        return response.habit
    }

    /// PUT `/dailyhabits/{habitId}?userId=...&oauthId=...`
    func updateHabit(habitId: String, userId: String, habit: UpdateDailyHabitRequestDTO, oauthId: String? = nil) async throws -> DailyHabitDTO {
        try await client.request(
            .put,
            path: "dailyhabits/\(habitId)",
            query: ["userId": userId, "oauthId": oauthId],
            headers: [:],
            body: habit
        )
    }

    /// DELETE `/dailyhabits/{habitId}?userId=...&oauthId=...`
    func deleteHabit(habitId: String, userId: String, oauthId: String? = nil) async throws -> [String: JSONValue] {
        try await client.request(
            .delete,
            path: "dailyhabits/\(habitId)",
            query: ["userId": userId, "oauthId": oauthId],
            headers: [:],
            body: nil
        )
    }

    /// POST `/dailyhabits/{habitId}/log?userId=...&oauthId=...` (backend returns `{ message, habit }`)
    func logCompletion(habitId: String, userId: String, completion: LogHabitCompletionRequestDTO, oauthId: String? = nil) async throws -> DailyHabitDTO {
        struct Response: Codable { let message: String; let habit: DailyHabitDTO }
        let response: Response = try await client.request(
            .post,
            path: "dailyhabits/\(habitId)/log",
            query: ["userId": userId, "oauthId": oauthId],
            headers: [:],
            body: completion
        )
        return response.habit
    }

    /// PATCH `/dailyhabits/{habitId}/check-in?userId=...&oauthId=...`
    func checkInHabit(habitId: String, userId: String, request: CheckInHabitRequestDTO = .init(value: nil, notes: nil), oauthId: String? = nil) async throws -> CheckInHabitResponseDTO {
        try await client.request(
            .patch,
            path: "dailyhabits/\(habitId)/check-in",
            query: ["userId": userId, "oauthId": oauthId],
            headers: [:],
            body: request
        )
    }

    /// PATCH `/dailyhabits/{habitId}/archive?userId=...&oauthId=...`
    func toggleArchive(habitId: String, userId: String, oauthId: String? = nil) async throws -> DailyHabitDTO {
        try await client.request(
            .patch,
            path: "dailyhabits/\(habitId)/archive",
            query: ["userId": userId, "oauthId": oauthId],
            headers: [:],
            body: JSONValue.object([:])
        )
    }

    /// GET `/dailyhabits/streaks?userId=...&minStreak=...`
    func getStreaks(userId: String, minStreak: Int = 0) async throws -> [HabitStreakDTO] {
        try await client.request(
            .get,
            path: "dailyhabits/streaks",
            query: ["userId": userId, "minStreak": String(minStreak)],
            headers: [:],
            body: nil
        )
    }

    /// GET `/dailyhabits/analytics?userId=...`
    func getAnalytics(userId: String, habitId: String? = nil, startDate: String? = nil, endDate: String? = nil) async throws -> HabitAnalyticsDTO {
        try await client.request(
            .get,
            path: "dailyhabits/analytics",
            query: ["userId": userId, "habitId": habitId, "startDate": startDate, "endDate": endDate],
            headers: [:],
            body: nil
        )
    }

    /// GET `/dailyhabits/{habitId}/logs`
    func getCompletionLogs(
        habitId: String,
        userId: String,
        oauthId: String? = nil,
        startDate: String? = nil,
        endDate: String? = nil,
        page: Int? = nil,
        pageSize: Int? = nil
    ) async throws -> [HabitCompletionLogEntryDTO] {
        try await client.request(
            .get,
            path: "dailyhabits/\(habitId)/logs",
            query: [
                "userId": userId,
                "oauthId": oauthId,
                "startDate": startDate,
                "endDate": endDate,
                "page": page.map(String.init),
                "pageSize": pageSize.map(String.init)
            ],
            headers: [:],
            body: nil
        )
    }

    /// GET `/dailyhabits/{habitId}/logs/{date}`
    func getCompletionLogByDate(habitId: String, date: String, userId: String, oauthId: String? = nil) async throws -> HabitCompletionLogEntryDTO {
        try await client.request(
            .get,
            path: "dailyhabits/\(habitId)/logs/\(date)",
            query: ["userId": userId, "oauthId": oauthId],
            headers: [:],
            body: nil
        )
    }
}

