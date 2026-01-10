import Foundation

struct HabitChallengesAPI: Sendable {
    let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }
}

enum ChallengeStatus: String, Codable, Sendable {
    case draft
    case active
    case completed
    case abandoned
}

enum ChallengePriority: String, Codable, Sendable {
    case high
    case medium
    case low
}

struct ChallengeHabitSummaryDTO: Codable, Sendable {
    let habitId: String
    let name: String
    let category: String
    let currentStreak: Int?
    let completionRate: Double?
    let isActive: Bool?
    let priority: String?
    let challengeSortOrder: Int?
    let linkedToChallengeAt: String?
}

struct ChallengeStatisticsDTO: Codable, Sendable {
    let daysInChallenge: Int?
    let daysRemaining: Int?
    let totalPossibleCompletions: Int?
    let actualCompletions: Int?
    let averageStreakLength: Double?
    let overallProgress: Double?
    let topPerformingHabit: String?
    let needsAttentionHabit: String?
}

struct HabitChallengeDTO: Codable, Sendable, Identifiable {
    let id: String
    let userId: String
    let oauthId: String?
    let title: String
    let description: String?
    let category: String?
    let color: String?
    let icon: String?
    let startDate: String?
    let endDate: String?
    let timeZone: String?
    let status: String?
    let priority: String?
    let targetCompletionRate: Double?
    let currentCompletionRate: Double?
    let totalHabitsCount: Int?
    let activeHabitsCount: Int?
    let isPinned: Bool?
    let isArchived: Bool?
    let archivedAt: String?
    let sortOrder: Int?
    let tags: String?
    let createdAt: String?
    let updatedAt: String?
    let habits: [ChallengeHabitSummaryDTO]?
    let statistics: ChallengeStatisticsDTO?
}

struct StandaloneHabitDTO: Codable, Sendable, Identifiable {
    let id: String
    let userId: String
    let oauthId: String?
    let name: String
    let description: String?
    let category: String
    let frequency: String?
    let priority: String?
    let currentStreak: Int?
    let completionRate: Double?
    let isActive: Bool?
    let createdAt: String?
}

struct CreateHabitChallengeRequestDTO: Codable, Sendable {
    let title: String
    let description: String?
    let category: String?
    let color: String?
    let icon: String?
    let startDate: String?
    let endDate: String?
    let timeZone: String?
    let priority: String?
    let targetCompletionRate: Double?
    let tags: String?
    let motivationText: String?
    let rewardText: String?
    let existingHabitIds: [String]?
}

struct UpdateHabitChallengeRequestDTO: Codable, Sendable {
    let title: String?
    let description: String?
    let category: String?
    let color: String?
    let icon: String?
    let startDate: String?
    let endDate: String?
    let timeZone: String?
    let priority: String?
    let targetCompletionRate: Double?
    let tags: String?
    let motivationText: String?
    let rewardText: String?
    let isPinned: Bool?
    let sortOrder: Int?
}

typealias ChallengeAnalyticsDTO = [String: JSONValue]

extension HabitChallengesAPI {
    /// GET `/HabitChallenges`
    func getUserChallenges(userId: String, status: String? = nil, category: String? = nil, isArchived: Bool? = nil, isPinned: Bool? = nil) async throws -> [HabitChallengeDTO] {
        try await client.request(
            .get,
            path: "HabitChallenges",
            query: [
                "userId": userId,
                "status": status,
                "category": category,
                "isArchived": isArchived.map(String.init),
                "isPinned": isPinned.map(String.init)
            ],
            headers: [:],
            body: nil
        )
    }

    /// GET `/HabitChallenges/{challengeId}?userId=...`
    func getChallengeById(challengeId: String, userId: String) async throws -> HabitChallengeDTO {
        try await client.request(
            .get,
            path: "HabitChallenges/\(challengeId)",
            query: ["userId": userId],
            headers: [:],
            body: nil
        )
    }

    /// GET `/HabitChallenges/standalone-habits?userId=...`
    func getStandaloneHabits(userId: String, isActive: Bool? = nil, category: String? = nil) async throws -> [StandaloneHabitDTO] {
        try await client.request(
            .get,
            path: "HabitChallenges/standalone-habits",
            query: ["userId": userId, "isActive": isActive.map(String.init), "category": category],
            headers: [:],
            body: nil
        )
    }

    /// GET `/HabitChallenges/{challengeId}/analytics?userId=...`
    func getChallengeAnalytics(challengeId: String, userId: String) async throws -> ChallengeAnalyticsDTO {
        try await client.request(
            .get,
            path: "HabitChallenges/\(challengeId)/analytics",
            query: ["userId": userId],
            headers: [:],
            body: nil
        )
    }

    /// POST `/HabitChallenges?userId=...`
    func createChallenge(userId: String, request: CreateHabitChallengeRequestDTO) async throws -> HabitChallengeDTO {
        try await client.request(.post, path: "HabitChallenges", query: ["userId": userId], headers: [:], body: request)
    }

    /// PUT `/HabitChallenges/{challengeId}?userId=...`
    func updateChallenge(challengeId: String, userId: String, request: UpdateHabitChallengeRequestDTO) async throws -> HabitChallengeDTO {
        try await client.request(.put, path: "HabitChallenges/\(challengeId)", query: ["userId": userId], headers: [:], body: request)
    }

    /// DELETE `/HabitChallenges/{challengeId}?userId=...&orphanHabits=...`
    func deleteChallenge(challengeId: String, userId: String, orphanHabits: Bool = true) async throws -> [String: JSONValue] {
        try await client.request(
            .delete,
            path: "HabitChallenges/\(challengeId)",
            query: ["userId": userId, "orphanHabits": String(orphanHabits)],
            headers: [:],
            body: nil
        )
    }

    /// POST `/HabitChallenges/{challengeId}/habits/{habitId}?userId=...&sortOrder=...`
    func linkHabitToChallenge(challengeId: String, habitId: String, userId: String, sortOrder: Int? = nil) async throws -> HabitChallengeDTO {
        try await client.request(
            .post,
            path: "HabitChallenges/\(challengeId)/habits/\(habitId)",
            query: ["userId": userId, "sortOrder": sortOrder.map(String.init)],
            headers: [:],
            body: JSONValue.object([:])
        )
    }

    /// DELETE `/HabitChallenges/{challengeId}/habits/{habitId}?userId=...`
    func unlinkHabitFromChallenge(challengeId: String, habitId: String, userId: String) async throws -> HabitChallengeDTO {
        try await client.request(
            .delete,
            path: "HabitChallenges/\(challengeId)/habits/\(habitId)",
            query: ["userId": userId],
            headers: [:],
            body: nil
        )
    }

    /// PATCH `/HabitChallenges/{challengeId}/archive?userId=...`
    func toggleArchive(challengeId: String, userId: String) async throws -> HabitChallengeDTO {
        try await client.request(
            .patch,
            path: "HabitChallenges/\(challengeId)/archive",
            query: ["userId": userId],
            headers: [:],
            body: JSONValue.object([:])
        )
    }

    /// PATCH `/HabitChallenges/{challengeId}/status?userId=...&status=...`
    func updateChallengeStatus(challengeId: String, userId: String, status: String) async throws -> HabitChallengeDTO {
        try await client.request(
            .patch,
            path: "HabitChallenges/\(challengeId)/status",
            query: ["userId": userId, "status": status],
            headers: [:],
            body: JSONValue.object([:])
        )
    }

    /// PATCH `/HabitChallenges/{challengeId}/reorder?userId=...`
    func reorderChallengeHabits(challengeId: String, userId: String, habitOrders: [String: Int]) async throws -> HabitChallengeDTO {
        try await client.request(
            .patch,
            path: "HabitChallenges/\(challengeId)/reorder",
            query: ["userId": userId],
            headers: [:],
            body: habitOrders
        )
    }
}

