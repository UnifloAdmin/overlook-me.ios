import Foundation

struct ChecklistAPI: Sendable {
    let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }
}

struct ChecklistItemDTO: Codable, Sendable, Identifiable {
    let id: String
    let checklistId: String?
    let title: String
    let description: String?
    let isCompleted: Bool?
    let completedAt: String?
    let completedBy: String?
    let sortOrder: Int?
    let isOptional: Bool?
}

struct ChecklistDTO: Codable, Sendable, Identifiable {
    let id: String
    let userId: String
    let name: String
    let description: String?
    let category: String?
    let color: String?
    let icon: String?
    let isActive: Bool?
    let isTemplate: Bool?
    let isArchived: Bool?
    let archivedAt: String?
    let timesUsed: Int?
    let lastUsedAt: String?
    let sortOrder: Int?
    let tags: String?
    let items: [ChecklistItemDTO]?
    let createdAt: String?
    let updatedAt: String?
}

struct ChecklistUsageLogDTO: Codable, Sendable, Identifiable {
    let id: String
    let checklistId: String
    let userId: String
    let startedAt: String
    let completedAt: String?
    let dueDate: String?
    let itemsCompleted: Int
    let totalItems: Int
    let notes: String?
    let createdAt: String
}

struct CreateChecklistItemRequestDTO: Codable, Sendable {
    let title: String
    let description: String?
    let sortOrder: Int
    let isOptional: Bool?
}

struct CreateChecklistRequestDTO: Codable, Sendable {
    let userId: String
    let name: String
    let description: String?
    let category: String?
    let color: String?
    let icon: String?
    let isTemplate: Bool?
    let isArchived: Bool?
    let tags: String?
    let items: [CreateChecklistItemRequestDTO]
}

struct UpdateChecklistRequestDTO: Codable, Sendable {
    let userId: String
    let name: String
    let description: String?
    let category: String?
    let color: String?
    let icon: String?
    let isActive: Bool?
    let isTemplate: Bool?
    let isArchived: Bool?
    let tags: String?
    let items: [CreateChecklistItemRequestDTO]
}

struct CreateFromTemplateRequestDTO: Codable, Sendable {
    let templateId: String
    let userId: String
    let name: String
    let description: String?
    let category: String?
}

struct StartChecklistRequestDTO: Codable, Sendable {
    let userId: String
    let dueDate: String?
    let notes: String?
}

struct GetChecklistsParamsDTO: Codable, Sendable {
    let userId: String
    let type: String?
    let category: String?
    let search: String?
    let sortBy: String?
    let sortOrder: String?
    let page: Int?
    let pageSize: Int?
    let includeInactive: Bool?
}

typealias PaginatedChecklistResponseDTO = [String: JSONValue]

extension ChecklistAPI {
    /// GET `/checklists`
    func getChecklists(_ params: GetChecklistsParamsDTO) async throws -> JSONValue {
        try await client.request(
            .get,
            path: "checklists",
            query: [
                "userId": params.userId,
                "type": params.type,
                "category": params.category,
                "search": params.search,
                "sortBy": params.sortBy,
                "sortOrder": params.sortOrder,
                "page": params.page.map(String.init),
                "pageSize": params.pageSize.map(String.init),
                "includeInactive": params.includeInactive.map(String.init)
            ],
            headers: [:],
            body: nil
        )
    }

    /// GET `/checklists/{id}?userId=...`
    func getChecklistById(id: String, userId: String) async throws -> ChecklistDTO {
        try await client.request(
            .get,
            path: "checklists/\(id)",
            query: ["userId": userId],
            headers: [:],
            body: nil
        )
    }

    /// POST `/checklists`
    func createChecklist(_ request: CreateChecklistRequestDTO) async throws -> ChecklistDTO {
        try await client.request(.post, path: "checklists", query: [:], headers: [:], body: request)
    }

    /// PUT `/checklists/{id}`
    func updateChecklist(id: String, request: UpdateChecklistRequestDTO) async throws -> ChecklistDTO {
        try await client.request(.put, path: "checklists/\(id)", query: [:], headers: [:], body: request)
    }

    /// DELETE `/checklists/{id}?userId=...`
    func deleteChecklist(id: String, userId: String) async throws -> EmptyResponse {
        try await client.request(
            .delete,
            path: "checklists/\(id)",
            query: ["userId": userId],
            headers: [:],
            body: nil
        )
    }

    /// POST `/checklists/{id}/start`
    func startChecklist(id: String, request: StartChecklistRequestDTO) async throws -> ChecklistUsageLogDTO {
        try await client.request(.post, path: "checklists/\(id)/start", query: [:], headers: [:], body: request)
    }

    /// POST `/checklists/{id}/recycle?userId=...`
    func recycleChecklist(id: String, userId: String) async throws -> ChecklistDTO {
        try await client.request(
            .post,
            path: "checklists/\(id)/recycle",
            query: ["userId": userId],
            headers: [:],
            body: JSONValue.object([:]) // send {}
        )
    }

    /// PATCH `/checklists/{checklistId}/items/{itemId}/toggle?userId=...`
    func toggleChecklistItem(checklistId: String, itemId: String, userId: String) async throws -> ChecklistItemDTO {
        try await client.request(
            .patch,
            path: "checklists/\(checklistId)/items/\(itemId)/toggle",
            query: ["userId": userId],
            headers: [:],
            body: JSONValue.object([:]) // send {}
        )
    }

    /// GET `/checklists/{id}/usage-logs?userId=...`
    func getChecklistUsageLogs(id: String, userId: String) async throws -> [ChecklistUsageLogDTO] {
        try await client.request(
            .get,
            path: "checklists/\(id)/usage-logs",
            query: ["userId": userId],
            headers: [:],
            body: nil
        )
    }

    /// POST `/checklists/from-template/{templateId}`
    func createFromTemplate(_ request: CreateFromTemplateRequestDTO) async throws -> ChecklistDTO {
        struct Body: Codable { let userId: String; let name: String; let description: String?; let category: String? }
        let body = Body(userId: request.userId, name: request.name, description: request.description, category: request.category)
        return try await client.request(.post, path: "checklists/from-template/\(request.templateId)", query: [:], headers: [:], body: body)
    }
}

