import Foundation

struct DailyPlanningAPI: Sendable {
    let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }
}

enum PlanPriority: String, Codable, Sendable { case critical, high, medium, low }
enum PlanStatus: String, Codable, Sendable { case pending, inProgress = "in_progress", completed, cancelled, deferred }
enum EnergyLevel: String, Codable, Sendable { case high, medium, low }

struct DailyPlanItemDTO: Codable, Sendable, Identifiable {
    let id: String
    let userId: String
    let title: String
    let planDate: String
    let priority: PlanPriority?
    let description: String?
    let category: String?
    let estimatedDurationMinutes: Int?
    let actualDurationMinutes: Int?
    let scheduledTime: String?
    let energyLevel: EnergyLevel?
    let status: PlanStatus?
    let progressPercentage: Int?
    let sortOrder: Int?
    let relatedTaskId: String?
    let relatedGoalId: String?
    let relatedHabitId: String?
    let relatedEventId: String?
    let isArchived: Bool?
    let archivedAt: String?
    let createdAt: String?
    let updatedAt: String?
}

struct CreateDailyPlanItemRequestDTO: Codable, Sendable {
    let userId: String
    let title: String
    let planDate: String
    let priority: PlanPriority?
    let description: String?
    let category: String?
    let estimatedDurationMinutes: Int?
    let scheduledTime: String?
    let energyLevel: EnergyLevel?
    let color: String?
    let icon: String?
    let tags: String?
    let notes: String?
    let relatedTaskId: String?
    let relatedGoalId: String?
    let relatedHabitId: String?
    let relatedEventId: String?
    let timeZone: String?
    let metadataJson: String?
}

struct UpdateDailyPlanItemRequestDTO: Codable, Sendable {
    let id: String
    let userId: String
    let title: String?
    let description: String?
    let priority: PlanPriority?
    let planDate: String?
    let category: String?
    let estimatedDurationMinutes: Int?
    let scheduledTime: String?
    let status: PlanStatus?
    let energyLevel: EnergyLevel?
    let tags: String?
    let notes: String?
    let progressPercentage: Int?
    let relatedTaskId: String?
    let relatedGoalId: String?
    let relatedHabitId: String?
    let relatedEventId: String?
    let timeZone: String?
    let metadataJson: String?
}

struct MarkDailyPlanItemCompleteRequestDTO: Codable, Sendable {
    let id: String
    let userId: String
    let actualDurationMinutes: Int?
    let completionNotes: String?
}

struct UpdateDailyPlanItemProgressRequestDTO: Codable, Sendable {
    let id: String
    let userId: String
    let progressPercentage: Int
}

struct ReorderItemDTO: Codable, Sendable {
    let id: String
    let newSortOrder: Int
}

struct ReorderDailyPlanItemsRequestDTO: Codable, Sendable {
    let userId: String
    let planDate: String
    let items: [ReorderItemDTO]
}

extension DailyPlanningAPI {
    private var basePath: String { "productivity/daily-planning" }

    /// GET `/productivity/daily-planning`
    func getDailyPlanItems(query: [String: String?]) async throws -> [DailyPlanItemDTO] {
        try await client.request(.get, path: basePath, query: query, headers: [:], body: nil)
    }

    /// GET `/productivity/daily-planning/{id}` (web client also sends `id` and `userId` as query params)
    func getDailyPlanItemById(id: String, userId: String) async throws -> DailyPlanItemDTO {
        try await client.request(
            .get,
            path: "\(basePath)/\(id)",
            query: ["id": id, "userId": userId],
            headers: [:],
            body: nil
        )
    }

    /// POST `/productivity/daily-planning`
    func createDailyPlanItem(_ request: CreateDailyPlanItemRequestDTO) async throws -> DailyPlanItemDTO {
        try await client.request(.post, path: basePath, query: [:], headers: [:], body: request)
    }

    /// PUT `/productivity/daily-planning/{id}`
    func updateDailyPlanItem(id: String, request: UpdateDailyPlanItemRequestDTO) async throws -> DailyPlanItemDTO {
        try await client.request(.put, path: "\(basePath)/\(id)", query: [:], headers: [:], body: request)
    }

    /// DELETE `/productivity/daily-planning/{id}?userId=...`
    func deleteDailyPlanItem(id: String, userId: String) async throws -> [String: String] {
        try await client.request(.delete, path: "\(basePath)/\(id)", query: ["userId": userId], headers: [:], body: nil)
    }

    /// PATCH `/productivity/daily-planning/{id}/complete`
    func markDailyPlanItemComplete(_ request: MarkDailyPlanItemCompleteRequestDTO) async throws -> DailyPlanItemDTO {
        struct Body: Codable { let userId: String; let actualDurationMinutes: Int?; let completionNotes: String? }
        let body = Body(userId: request.userId, actualDurationMinutes: request.actualDurationMinutes, completionNotes: request.completionNotes)
        return try await client.request(.patch, path: "\(basePath)/\(request.id)/complete", query: [:], headers: [:], body: body)
    }

    /// PATCH `/productivity/daily-planning/{id}/progress`
    func updateDailyPlanItemProgress(_ request: UpdateDailyPlanItemProgressRequestDTO) async throws -> DailyPlanItemDTO {
        struct Body: Codable { let userId: String; let progressPercentage: Int }
        let body = Body(userId: request.userId, progressPercentage: request.progressPercentage)
        return try await client.request(.patch, path: "\(basePath)/\(request.id)/progress", query: [:], headers: [:], body: body)
    }

    /// PUT `/productivity/daily-planning/reorder`
    func reorderDailyPlanItems(_ request: ReorderDailyPlanItemsRequestDTO) async throws -> [String: JSONValue] {
        try await client.request(.put, path: "\(basePath)/reorder", query: [:], headers: [:], body: request)
    }
}

