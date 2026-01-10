import Foundation

struct SubTasksAPI: Sendable {
    let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }
}

enum SubTaskStatus: String, Codable, Sendable {
    case pending
    case inProgress = "in_progress"
    case completed
    case cancelled
}

enum SubTaskPriority: String, Codable, Sendable {
    case critical
    case high
    case medium
    case low
}

struct SubTaskDTO: Codable, Sendable, Identifiable {
    let id: String
    let taskId: String
    let userId: String
    let title: String

    let description: String?
    let status: SubTaskStatus?
    let sortOrder: Int?
    let isCompleted: Bool?
    let priority: SubTaskPriority?
    let progressPercentage: Int?

    let dueDateTime: String?
    let createdAt: String?
    let updatedAt: String?
}

struct GetSubTasksRequestDTO: Codable, Sendable {
    let type: String?
    let taskId: String?
    let subTaskId: String?
    let userId: String?
    let status: SubTaskStatus?
    let priority: SubTaskPriority?
    let isCompleted: Bool?
    let assignedTo: String?
    let search: String?
    let sortBy: String?
    let sortOrder: String?
    let page: Int?
    let pageSize: Int?
    let includeDeleted: Bool?
}

struct CreateSubTaskRequestDTO: Codable, Sendable {
    let taskId: String
    let userId: String
    let title: String
    let description: String?
    let status: SubTaskStatus?
    let priority: SubTaskPriority?
    let estimatedDurationMinutes: Int?
    let dueDateTime: String?
    let assignedTo: String?
    let notes: String?
}

struct UpdateSubTaskRequestDTO: Codable, Sendable {
    let userId: String
    let title: String?
    let description: String?
    let status: SubTaskStatus?
    let priority: SubTaskPriority?
    let estimatedDurationMinutes: Int?
    let actualDurationMinutes: Int?
    let dueDateTime: String?
    let assignedTo: String?
    let progressPercentage: Int?
    let notes: String?
    let sortOrder: Int?
    let isCompleted: Bool?
}

struct SubTaskResponseDTO: Codable, Sendable {
    let message: String
    let subTask: SubTaskDTO
}

// Keep pagination response flexible (backend sometimes returns array vs paged object).
typealias SubTasksPagedResponseDTO = [String: JSONValue]

extension SubTasksAPI {
    /// GET `/SubTasks`
    func getSubTasks(_ request: GetSubTasksRequestDTO) async throws -> JSONValue {
        try await client.request(
            .get,
            path: "SubTasks",
            query: [
                "type": request.type,
                "taskId": request.taskId,
                "subTaskId": request.subTaskId,
                "userId": request.userId,
                "status": request.status?.rawValue,
                "priority": request.priority?.rawValue,
                "isCompleted": request.isCompleted.map(String.init),
                "assignedTo": request.assignedTo,
                "search": request.search,
                "sortBy": request.sortBy,
                "sortOrder": request.sortOrder,
                "page": request.page.map(String.init),
                "pageSize": request.pageSize.map(String.init),
                "includeDeleted": request.includeDeleted.map(String.init)
            ],
            headers: [:],
            body: nil
        )
    }

    /// GET `/SubTasks?subTaskId=...`
    func getSubTaskById(_ subTaskId: String) async throws -> SubTaskDTO {
        try await client.request(
            .get,
            path: "SubTasks",
            query: ["subTaskId": subTaskId],
            headers: [:],
            body: nil
        )
    }

    /// POST `/SubTasks`
    func createSubTask(_ request: CreateSubTaskRequestDTO) async throws -> SubTaskResponseDTO {
        try await client.request(.post, path: "SubTasks", query: [:], headers: [:], body: request)
    }

    /// PUT `/SubTasks/{id}`
    func updateSubTask(subTaskId: String, request: UpdateSubTaskRequestDTO) async throws -> SubTaskResponseDTO {
        try await client.request(.put, path: "SubTasks/\(subTaskId)", query: [:], headers: [:], body: request)
    }

    /// DELETE `/SubTasks/{id}?userId=...`
    func deleteSubTask(subTaskId: String, userId: String) async throws -> [String: String] {
        try await client.request(
            .delete,
            path: "SubTasks/\(subTaskId)",
            query: ["userId": userId],
            headers: [:],
            body: nil
        )
    }
}

