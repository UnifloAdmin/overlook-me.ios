import Foundation

// MARK: - DTOs

struct QuitVapeProfileDTO: Codable, Sendable {
    let id: String
    let userId: String
    let oauthId: String?
    let quitDate: String
    let dailyVapeCostCents: Int
    let nicotineMgPerDay: Double
    let vapeProductType: String
    let motivationNotes: String?
    let isActive: Bool
    let currentStreakDays: Int
    let longestStreakDays: Int
    let totalCravingsResisted: Int
    let totalCravingsGivenIn: Int
    let moneySavedCents: Int
    let lifeRegainedMinutes: Int
    let lastRelapseAt: String?
    let createdAt: String
    let updatedAt: String?
}

struct VapeCravingLogDTO: Codable, Sendable, Identifiable {
    let id: String
    let profileId: String
    let userId: String
    let intensity: Int
    let trigger: String
    let resisted: Bool
    let durationSeconds: Int?
    let notes: String?
    let copingStrategy: String?
    let location: String?
    let puffCount: Int
    let occurredAt: String
    let createdAt: String
}

struct HealthMilestoneDTO: Codable, Sendable {
    let title: String
    let description: String
    let requiredMinutes: Int
    let isAchieved: Bool
    let progressPercent: Double
    let icon: String
}

struct CravingTrendDTO: Codable, Sendable {
    let thisWeekCount: Int
    let lastWeekCount: Int
    let changePercent: Double
    let byTrigger: [String: Int]?
    let byDayOfWeek: [String: Int]?
    let averageIntensity: Double
}

struct QuitVapeDashboardDTO: Codable, Sendable {
    let profile: QuitVapeProfileDTO
    let daysQuit: Int
    let moneySavedDollars: Double
    let totalCravings: Int
    let resistRate: Double
    let healthMilestones: [HealthMilestoneDTO]
    let recentCravings: [VapeCravingLogDTO]
    let weeklyTrend: CravingTrendDTO?
}

struct CreateQuitVapeProfileRequestDTO: Codable, Sendable {
    let quitDate: String?
    let dailyVapeCostCents: Int?
    let nicotineMgPerDay: Double?
    let vapeProductType: String?
    let motivationNotes: String?
}

struct LogCravingRequestDTO: Codable, Sendable {
    let intensity: Int
    let trigger: String
    let resisted: Bool
    let durationSeconds: Int?
    let notes: String?
    let copingStrategy: String?
    let location: String?
    let puffCount: Int?
    let occurredAt: String?
}

// MARK: - API

struct QuitVapeAPI: Sendable {
    let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }

    /// GET `/quitvape/dashboard?userId=...`
    func getDashboard(userId: String, profileId: String? = nil) async throws -> QuitVapeDashboardDTO {
        try await client.request(
            .get,
            path: "quitvape/dashboard",
            query: ["userId": userId, "profileId": profileId],
            headers: [:],
            body: nil
        )
    }

    /// POST `/quitvape?userId=...`
    func createProfile(userId: String, request: CreateQuitVapeProfileRequestDTO? = nil) async throws -> QuitVapeProfileDTO {
        struct Response: Codable { let message: String; let profile: QuitVapeProfileDTO }
        let response: Response = try await client.request(
            .post,
            path: "quitvape",
            query: ["userId": userId],
            headers: [:],
            body: request
        )
        return response.profile
    }

    /// GET `/quitvape/:profileId/cravings?userId=...`
    func getCravings(profileId: String, userId: String, startDate: String? = nil, endDate: String? = nil) async throws -> [VapeCravingLogDTO] {
        try await client.request(
            .get,
            path: "quitvape/\(profileId)/cravings",
            query: ["userId": userId, "startDate": startDate, "endDate": endDate],
            headers: [:],
            body: nil
        )
    }

    /// POST `/quitvape/:profileId/cravings?userId=...`
    func logCraving(profileId: String, userId: String, request: LogCravingRequestDTO) async throws -> VapeCravingLogDTO {
        struct Response: Codable { let message: String; let craving: VapeCravingLogDTO }
        let response: Response = try await client.request(
            .post,
            path: "quitvape/\(profileId)/cravings",
            query: ["userId": userId],
            headers: [:],
            body: request
        )
        return response.craving
    }
}
