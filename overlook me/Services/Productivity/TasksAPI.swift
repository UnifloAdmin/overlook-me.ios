import Foundation

struct TasksAPI: Sendable {
    let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }
}

// MARK: - DTOs

enum TaskStatus: String, Codable, Sendable {
    case pending
    case inProgress = "in_progress"
    case completed
    case cancelled
    case onHold = "on_hold"
}

enum TaskPriority: String, Codable, Sendable {
    case critical
    case high
    case medium
    case low
}

struct TaskDTO: Codable, Sendable, Identifiable {
    let id: String
    let userId: String
    let title: String

    let description: String?
    let descriptionFormat: String?
    let status: TaskStatus?
    let priority: TaskPriority?

    let scheduledDate: String?
    let scheduledTime: String?
    let dueDateTime: String?
    
    let estimatedDurationMinutes: Int?
    let category: String?
    let project: String?
    let tags: String?
    let color: String?

    let progressPercentage: Int?
    let location: String?
    let latitude: Double?
    let longitude: Double?
    
    let isPinned: Bool?
    let isArchived: Bool?
    let isBlocked: Bool?
    let isProModeEnabled: Bool?
    let isFuture: Bool?
    
    let importanceScore: Int?
    let createdAt: String?
    let updatedAt: String?
}

struct TaskReminderDTO: Codable, Sendable {
    let type: String
    let minutesBefore: Int
}

struct AutoSaveTaskRequestDTO: Codable, Sendable {
    let taskId: String?
    let userId: String

    let title: String?
    let description: String?
    let descriptionFormat: String?
    let status: TaskStatus?
    let priority: TaskPriority?

    let scheduledDate: String?
    let scheduledTime: String?
    let dueDateTime: String?
    let estimatedDurationMinutes: Int?
    let category: String?
    let project: String?
    let tags: String?
    let color: String?
    let progressPercentage: Int?
    let location: String?
    let latitude: Double?
    let longitude: Double?
    let isProModeEnabled: Bool?
    let isFuture: Bool?
    let lastKnownUpdatedAt: String?
}

struct AutoSaveTaskResponseDTO: Codable, Sendable {
    let id: String
    let title: String
    let description: String?
    let status: TaskStatus
    let priority: TaskPriority

    let scheduledDate: String?
    let scheduledTime: String?
    let dueDateTime: String?
    let category: String?
    let project: String?
    let tags: String?
    let color: String?
    let progressPercentage: Int

    let location: String?
    let latitude: Double?
    let longitude: Double?

    let importanceScore: Double?
    let createdAt: String
    let updatedAt: String

    let isNewTask: Bool
    let conflictDetected: Bool
    let conflictMessage: String?
}

struct GetTasksRequestDTO: Codable, Sendable {
    let userId: String
    let taskId: String?
    let status: TaskStatus?
    let priority: TaskPriority?
    let category: String?
    let project: String?
    let date: String?
    let isPinned: Bool?
    let isArchived: Bool?
    let overdue: Bool?
    let includeCompleted: Bool?
}

struct TaskAnalyticsRequestDTO: Codable, Sendable {
    let userId: String
    let startDate: String?
    let endDate: String?
    let includeArchived: Bool?
    let project: String?
    let category: String?
}

// Keep analytics response flexible (it’s large and changes often).
typealias TaskAnalyticsResponseDTO = [String: JSONValue]

// MARK: - Endpoints

extension TasksAPI {
    /// GET `/Tasks` with query params.
    func getTasks(_ request: GetTasksRequestDTO) async throws -> [TaskDTO] {
        try await client.request(
            .get,
            path: "Tasks",
            query: [
                "userId": request.userId,
                "taskId": request.taskId,
                "status": request.status?.rawValue,
                "priority": request.priority?.rawValue,
                "category": request.category,
                "project": request.project,
                "date": request.date,
                "isPinned": request.isPinned.map(String.init),
                "isArchived": request.isArchived.map(String.init),
                "overdue": request.overdue.map(String.init),
                "includeCompleted": request.includeCompleted.map(String.init)
            ],
            headers: [:],
            body: nil
        )
    }

    /// GET `/Tasks?userId={userId}&taskId={taskId}` (backend expects query params, not route params).
    func getTaskById(taskId: String, userId: String) async throws -> TaskDTO {
        try await client.request(
            .get,
            path: "Tasks",
            query: ["userId": userId, "taskId": taskId],
            headers: [:],
            body: nil
        )
    }

    /// POST `/Tasks`
    func autoSaveTask(_ request: AutoSaveTaskRequestDTO) async throws -> AutoSaveTaskResponseDTO {
        try await client.request(.post, path: "Tasks", query: [:], headers: [:], body: request)
    }

    /// PUT `/Tasks/{taskId}`
    func updateTask(taskId: String, request: AutoSaveTaskRequestDTO) async throws -> AutoSaveTaskResponseDTO {
        try await client.request(.put, path: "Tasks/\(taskId)", query: [:], headers: [:], body: request)
    }

    /// DELETE `/Tasks/{taskId}?userId={userId}`
    func deleteTask(taskId: String, userId: String) async throws -> [String: String] {
        try await client.request(
            .delete,
            path: "Tasks/\(taskId)",
            query: ["userId": userId],
            headers: [:],
            body: nil
        )
    }

    /// GET `/Tasks/analytics`
    func getAnalytics(_ request: TaskAnalyticsRequestDTO) async throws -> TaskAnalyticsResponseDTO {
        try await client.request(
            .get,
            path: "Tasks/analytics",
            query: [
                "userId": request.userId,
                "startDate": request.startDate,
                "endDate": request.endDate,
                "includeArchived": request.includeArchived.map(String.init),
                "project": request.project,
                "category": request.category
            ],
            headers: [:],
            body: nil
        )
    }
}

