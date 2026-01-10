import Foundation

struct GamificationAPI: Sendable {
    let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }
}

typealias GamificationProfileDTO = [String: JSONValue]
typealias AchievementDTO = [String: JSONValue]
typealias BadgeDTO = [String: JSONValue]
typealias StreakDTO = [String: JSONValue]
typealias GamificationStatsDTO = [String: JSONValue]
typealias RecentActivityDTO = [String: JSONValue]
typealias XPAwardResponseDTO = [String: JSONValue]
typealias AchievementUnlockDTO = [String: JSONValue]
typealias AchievementProgressDTO = [String: JSONValue]

struct AwardXPRequestDTO: Codable, Sendable {
    let actionType: String
    let amount: Int
}

struct UpdateStreakRequestDTO: Codable, Sendable {
    let streakType: String
}

extension GamificationAPI {
    private var basePath: String { "gamification" }

    /// GET `/gamification/profile/{userId}`
    func getUserProfile(userId: String) async throws -> GamificationProfileDTO {
        try await client.request(.get, path: "\(basePath)/profile/\(userId)", query: [:], headers: [:], body: nil)
    }

    /// POST `/gamification/xp/{userId}`
    func awardXP(userId: String, actionType: String, amount: Int) async throws -> XPAwardResponseDTO {
        try await client.request(.post, path: "\(basePath)/xp/\(userId)", query: [:], headers: [:], body: AwardXPRequestDTO(actionType: actionType, amount: amount))
    }

    /// POST `/gamification/achievements/{userId}/check`
    func checkAndUnlockAchievements(userId: String) async throws -> [AchievementUnlockDTO] {
        try await client.request(.post, path: "\(basePath)/achievements/\(userId)/check", query: [:], headers: [:], body: JSONValue.object([:]))
    }

    /// GET `/gamification/achievements/{userId}/all`
    func getAllAchievements(userId: String) async throws -> [AchievementDTO] {
        try await client.request(.get, path: "\(basePath)/achievements/\(userId)/all", query: [:], headers: [:], body: nil)
    }

    /// GET `/gamification/achievements/{userId}/{achievementId}/progress`
    func getAchievementProgress(userId: String, achievementId: Int) async throws -> AchievementProgressDTO {
        try await client.request(.get, path: "\(basePath)/achievements/\(userId)/\(achievementId)/progress", query: [:], headers: [:], body: nil)
    }

    /// GET `/gamification/achievements/{userId}/progress`
    func getAllAchievementProgress(userId: String) async throws -> [AchievementProgressDTO] {
        try await client.request(.get, path: "\(basePath)/achievements/\(userId)/progress", query: [:], headers: [:], body: nil)
    }

    /// POST `/gamification/streaks/{userId}`
    func updateStreak(userId: String, streakType: String) async throws -> StreakDTO {
        try await client.request(.post, path: "\(basePath)/streaks/\(userId)", query: [:], headers: [:], body: UpdateStreakRequestDTO(streakType: streakType))
    }

    /// GET `/gamification/streaks/{userId}`
    func getActiveStreaks(userId: String) async throws -> [StreakDTO] {
        try await client.request(.get, path: "\(basePath)/streaks/\(userId)", query: [:], headers: [:], body: nil)
    }

    /// GET `/gamification/stats/{userId}`
    func getStats(userId: String) async throws -> GamificationStatsDTO {
        try await client.request(.get, path: "\(basePath)/stats/\(userId)", query: [:], headers: [:], body: nil)
    }

    /// GET `/gamification/activity/{userId}?limit=...`
    func getRecentActivity(userId: String, limit: Int = 10) async throws -> [RecentActivityDTO] {
        try await client.request(.get, path: "\(basePath)/activity/\(userId)", query: ["limit": String(limit)], headers: [:], body: nil)
    }
}

