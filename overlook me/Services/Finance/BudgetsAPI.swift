import Foundation

struct BudgetsAPI: Sendable {
    let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }
}

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

typealias BudgetProgressDTO = [String: JSONValue]
typealias BudgetAlertDTO = [String: JSONValue]

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

typealias CheckAlertsResponseDTO = [String: JSONValue]

extension BudgetsAPI {
    /// GET `/budgets` (unified endpoint; response varies by `type`)
    func getBudgets(query: [String: String?]) async throws -> JSONValue {
        try await client.request(.get, path: "budgets", query: query, headers: [:], body: nil)
    }

    /// POST `/budgets`
    func createBudget(_ request: CreateBudgetRequestDTO) async throws -> BudgetDTO {
        try await client.request(.post, path: "budgets", query: [:], headers: [:], body: request)
    }

    /// PUT `/budgets/{budgetId}`
    func updateBudget(budgetId: Int, request: UpdateBudgetRequestDTO) async throws -> BudgetDTO {
        try await client.request(.put, path: "budgets/\(budgetId)", query: [:], headers: [:], body: request)
    }

    /// DELETE `/budgets/{budgetId}?userId=...`
    func deleteBudget(budgetId: Int, userId: String) async throws -> [String: JSONValue] {
        try await client.request(.delete, path: "budgets/\(budgetId)", query: ["userId": userId], headers: [:], body: nil)
    }

    /// POST `/budgets/user/{userId}/check-alerts`
    func checkAlerts(userId: String) async throws -> CheckAlertsResponseDTO {
        try await client.request(.post, path: "budgets/user/\(userId)/check-alerts", query: [:], headers: [:], body: JSONValue.object([:]))
    }

    /// PATCH `/budgets/alerts/{alertId}/read?userId=...`
    func markAlertAsRead(alertId: Int, userId: String) async throws -> EmptyResponse {
        try await client.request(.patch, path: "budgets/alerts/\(alertId)/read", query: ["userId": userId], headers: [:], body: JSONValue.object([:]))
    }

    /// PATCH `/budgets/user/{userId}/alerts/read-all`
    func markAllAlertsAsRead(userId: String) async throws -> EmptyResponse {
        try await client.request(.patch, path: "budgets/user/\(userId)/alerts/read-all", query: [:], headers: [:], body: JSONValue.object([:]))
    }
}

