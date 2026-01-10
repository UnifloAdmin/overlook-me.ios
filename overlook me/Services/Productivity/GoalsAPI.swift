import Foundation

struct GoalsAPI: Sendable {
    let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }
}

// MARK: - DTOs

enum GoalCategory: Int, Codable, Sendable {
    case financial = 0
    case career = 1
    case health = 2
    case personal = 3
    case education = 4
    case relationship = 5
    case business = 6
    case creative = 7
    case social = 8
    case spiritual = 9
    case other = 10
}

enum GoalStatus: Int, Codable, Sendable {
    case draft = 0
    case active = 1
    case onTrack = 2
    case atRisk = 3
    case behind = 4
    case completed = 5
    case cancelled = 6
    case onHold = 7
    case archived = 8
    case deleted = 9
}

enum TimeframeType: Int, Codable, Sendable {
    case daily = 0
    case weekly = 1
    case monthly = 2
    case quarterly = 3
    case yearly = 4
    case custom = 5
    case longTerm = 6
}

enum ScoringMethod: Int, Codable, Sendable {
    case percentage = 0
    case binary = 1
    case milestone = 2
    case keyResults = 3
    case weighted = 4
    case custom = 5
}

enum ReviewCycle: Int, Codable, Sendable {
    case none = 0
    case daily = 1
    case weekly = 2
    case biWeekly = 3
    case monthly = 4
    case quarterly = 5
    case yearly = 6
    case custom = 7
}

enum KeyResultType: Int, Codable, Sendable {
    case numeric = 0
    case boolean = 1
    case percentage = 2
    case currency = 3
    case count = 4
    case custom = 5
}

enum ConfidenceLevel: Int, Codable, Sendable {
    case veryLow = 0
    case low = 1
    case medium = 2
    case high = 3
    case veryHigh = 4
    case certain = 5
}

struct KeyResultDTO: Codable, Sendable, Identifiable {
    let id: String
    let goalId: String?
    let title: String
    let description: String?
    let type: KeyResultType?
    let startValue: Double?
    let currentValue: Double?
    let targetValue: Double?
    let unit: String?
    let weight: Double?
    let progressPercentage: Double?
    let dueDate: String?
    let confidenceLevel: ConfidenceLevel?
    let isCompleted: Bool?
    let createdAt: String?
    let updatedAt: String?
}

struct MilestoneDTO: Codable, Sendable, Identifiable {
    let id: String
    let goalId: String?
    let title: String
    let description: String?
    let targetDate: String
    let isCompleted: Bool
    let completedDate: String?
    let order: Int?
    let createdAt: String?
}

struct GoalDTO: Codable, Sendable, Identifiable {
    let id: String
    let userId: String
    let title: String
    let description: String?

    let category: GoalCategory?
    let status: GoalStatus?
    let priority: String?
    let timeframe: TimeframeType?

    let startDate: String?
    let targetDate: String?
    let completedDate: String?

    let progressPercentage: Double?
    let scoringMethod: ScoringMethod?
    let confidenceLevel: ConfidenceLevel?
    let reviewCycle: ReviewCycle?

    let isPinned: Bool?
    let isArchived: Bool?

    let keyResults: [KeyResultDTO]?
    let milestones: [MilestoneDTO]?

    let createdAt: String?
    let updatedAt: String?
}

struct CreateGoalRequestDTO: Codable, Sendable {
    let title: String
    let description: String?
    let category: GoalCategory
    let priority: String?
    let timeframe: TimeframeType
    let startDate: String?
    let targetDate: String?
    let scoringMethod: ScoringMethod?
    let reviewCycle: ReviewCycle?
    let parentGoalId: String?
    let color: String?
    let icon: String?
    let tags: String?
    let isPinned: Bool?
    let visibility: String?
    let relatedBudgetId: String?
    let successCriteria: String?
    let keyResults: [JSONValue]?
    let milestones: [JSONValue]?
}

struct UpdateGoalRequestDTO: Codable, Sendable {
    let title: String?
    let description: String?
    let category: GoalCategory?
    let status: GoalStatus?
    let priority: String?
    let timeframe: TimeframeType?
    let targetDate: String?
    let progressPercentage: Double?
    let isProgressAutoCalculated: Bool?
    let confidenceLevel: ConfidenceLevel?
    let reviewCycle: ReviewCycle?
    let color: String?
    let icon: String?
    let tags: String?
    let isPinned: Bool?
    let successCriteria: String?
    let lessonsLearned: String?
}

struct UpdateKeyResultProgressRequestDTO: Codable, Sendable {
    let currentValue: Double
    let notes: String?
    let confidenceLevel: ConfidenceLevel?
}

extension GoalsAPI {
    /// GET `/goals`
    func getGoals(
        userId: String,
        category: GoalCategory? = nil,
        status: GoalStatus? = nil,
        priority: String? = nil,
        timeframe: TimeframeType? = nil,
        isPinned: Bool? = nil,
        isArchived: Bool? = nil,
        searchTerm: String? = nil,
        parentGoalId: String? = nil,
        dueBefore: String? = nil,
        dueAfter: String? = nil
    ) async throws -> [GoalDTO] {
        try await client.request(
            .get,
            path: "goals",
            query: [
                "userId": userId,
                "category": category.map { String($0.rawValue) },
                "status": status.map { String($0.rawValue) },
                "priority": priority,
                "timeframe": timeframe.map { String($0.rawValue) },
                "isPinned": isPinned.map(String.init),
                "isArchived": isArchived.map(String.init),
                "searchTerm": searchTerm,
                "parentGoalId": parentGoalId,
                "dueBefore": dueBefore,
                "dueAfter": dueAfter
            ],
            headers: [:],
            body: nil
        )
    }

    /// GET `/goals/{goalId}?userId=...`
    func getGoalById(goalId: String, userId: String) async throws -> GoalDTO {
        try await client.request(
            .get,
            path: "goals/\(goalId)",
            query: ["userId": userId],
            headers: [:],
            body: nil
        )
    }

    /// GET `/goals/due-soon?userId=...&daysAhead=...`
    func getDueSoonGoals(userId: String, daysAhead: Int = 7) async throws -> [GoalDTO] {
        try await client.request(
            .get,
            path: "goals/due-soon",
            query: ["userId": userId, "daysAhead": String(daysAhead)],
            headers: [:],
            body: nil
        )
    }

    /// GET `/goals/overdue?userId=...`
    func getOverdueGoals(userId: String) async throws -> [GoalDTO] {
        try await client.request(.get, path: "goals/overdue", query: ["userId": userId], headers: [:], body: nil)
    }

    /// POST `/goals?userId=...`
    func createGoal(userId: String, goal: CreateGoalRequestDTO) async throws -> GoalDTO {
        try await client.request(.post, path: "goals", query: ["userId": userId], headers: [:], body: goal)
    }

    /// PUT `/goals/{goalId}?userId=...`
    func updateGoal(goalId: String, userId: String, goal: UpdateGoalRequestDTO) async throws -> GoalDTO {
        try await client.request(.put, path: "goals/\(goalId)", query: ["userId": userId], headers: [:], body: goal)
    }

    /// DELETE `/goals/{goalId}?userId=...`
    func deleteGoal(goalId: String, userId: String) async throws -> [String: JSONValue] {
        try await client.request(.delete, path: "goals/\(goalId)", query: ["userId": userId], headers: [:], body: nil)
    }

    /// PUT `/goals/key-results/{keyResultId}/progress?userId=...`
    func updateKeyResultProgress(keyResultId: String, userId: String, progress: UpdateKeyResultProgressRequestDTO) async throws -> KeyResultDTO {
        try await client.request(
            .put,
            path: "goals/key-results/\(keyResultId)/progress",
            query: ["userId": userId],
            headers: [:],
            body: progress
        )
    }
}

