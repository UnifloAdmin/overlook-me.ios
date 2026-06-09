import Foundation

struct BudgetsAPI: Sendable {
    let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }
}

// MARK: - DTOs

struct BudgetDTO: Codable, Sendable {
    let id: Int
    let userId: String
    let name: String
    let categoryId: Int?
    let amount: Double
    let period: String
    let startDate: String?
    let endDate: String?
    let alertThreshold: Double?
    let isActive: Bool?
    let createdAt: String?
    let updatedAt: String?
}

struct BudgetProgressDTO: Codable, Sendable, Identifiable {
    var id: Int { budgetId }
    let budgetId: Int
    let budgetName: String
    let categoryId: Int?
    let categoryName: String?
    let period: String
    let periodStartDate: String
    let periodEndDate: String
    let budgetAmount: Double
    let spentAmount: Double
    let remainingAmount: Double
    let percentageUsed: Double
    let isOverBudget: Bool
    let daysInPeriod: Int
    let daysElapsed: Int
    let daysRemaining: Int
    let dailyAverage: Double
    let projectedSpending: Double
    let recommendedDailySpend: Double

    var status: BudgetStatus {
        if isOverBudget { return .over }
        if percentageUsed >= 80 { return .warning }
        return .onTrack
    }

    enum BudgetStatus {
        case onTrack, warning, over
    }
}

struct BudgetAlertDTO: Codable, Sendable, Identifiable {
    let id: Int
    let budgetId: Int
    let alertType: String
    let percentageUsed: Double
    let amountSpent: Double
    let message: String
    let isRead: Bool
    let createdAt: String
}

struct BudgetDailySnapshotDTO: Codable, Sendable, Identifiable {
    var id: String { date }
    let date: String
    let dailyAmount: Double
    let cumulativeAmount: Double
    let transactionCount: Int
    let periodStart: String
    let periodEnd: String
    let computedAt: String
}

struct BudgetSnapshotsResponseDTO: Codable, Sendable {
    let snapshots: [BudgetDailySnapshotDTO]

    init(from decoder: Decoder) throws {
        if let keyed = try? decoder.container(keyedBy: CodingKeys.self),
           let snaps = try? keyed.decode([BudgetDailySnapshotDTO].self, forKey: .snapshots) {
            snapshots = snaps
        } else {
            var unkeyedContainer = try decoder.unkeyedContainer()
            var snaps: [BudgetDailySnapshotDTO] = []
            while !unkeyedContainer.isAtEnd {
                snaps.append(try unkeyedContainer.decode(BudgetDailySnapshotDTO.self))
            }
            snapshots = snaps
        }
    }

    private enum CodingKeys: String, CodingKey { case snapshots }
}

struct CreateBudgetRequestDTO: Codable, Sendable {
    let userId: String
    let name: String
    let categoryId: Int?
    let amount: Double
    let period: String
    let startDate: String?
    let endDate: String?
    let alertThreshold: Double?
}

struct UpdateBudgetRequestDTO: Codable, Sendable {
    let userId: String
    let name: String
    let categoryId: Int?
    let amount: Double
    let period: String
    let startDate: String?
    let endDate: String?
    let alertThreshold: Double?
    let isActive: Bool
}

// MARK: - Endpoints

extension BudgetsAPI {
    func getBudgetProgress(userId: String) async throws -> [BudgetProgressDTO] {
        try await client.request(
            .get, path: "budgets",
            query: ["userId": userId, "type": "progress"],
            headers: [:], body: nil
        )
    }

    func getBudgetAlerts(userId: String, includeRead: Bool = false) async throws -> [BudgetAlertDTO] {
        try await client.request(
            .get, path: "budgets",
            query: ["userId": userId, "type": "alerts", "includeRead": includeRead ? "true" : "false"],
            headers: [:], body: nil
        )
    }

    func getBudgetSnapshots(budgetId: Int) async throws -> BudgetSnapshotsResponseDTO {
        try await client.request(
            .get, path: "budgets/\(budgetId)/snapshots",
            query: [:], headers: [:], body: nil
        )
    }

    func createBudget(_ request: CreateBudgetRequestDTO) async throws -> BudgetDTO {
        try await client.request(.post, path: "budgets", query: [:], headers: [:], body: request)
    }

    func updateBudget(budgetId: Int, request: UpdateBudgetRequestDTO) async throws -> BudgetDTO {
        try await client.request(.put, path: "budgets/\(budgetId)", query: [:], headers: [:], body: request)
    }

    func deleteBudget(budgetId: Int, userId: String) async throws -> [String: JSONValue] {
        try await client.request(
            .delete, path: "budgets/\(budgetId)",
            query: ["userId": userId], headers: [:], body: nil
        )
    }

    func markAlertAsRead(alertId: Int, userId: String) async throws -> EmptyResponse {
        try await client.request(
            .patch, path: "budgets/alerts/\(alertId)/read",
            query: ["userId": userId], headers: [:], body: JSONValue.object([:])
        )
    }

    func markAllAlertsAsRead(userId: String) async throws -> EmptyResponse {
        try await client.request(
            .patch, path: "budgets/user/\(userId)/alerts/read-all",
            query: [:], headers: [:], body: JSONValue.object([:])
        )
    }
}
