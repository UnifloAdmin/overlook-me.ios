import Foundation

struct TaskAnalyticsAPI: Sendable {
    let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }
}

struct TaskCompletionAnalyticsRequestDTO: Codable, Sendable {
    let userId: String
    let days: Int?
    let project: String?
    let category: String?
}

struct SubTaskCompletionAnalyticsRequestDTO: Codable, Sendable {
    let userId: String
    let days: Int?
    let taskId: String?
}

typealias TaskCompletionAnalyticsResponseDTO = [String: JSONValue]
typealias SubTaskCompletionAnalyticsResponseDTO = [String: JSONValue]
typealias TaskDetailedAnalyticsResponseDTO = [String: JSONValue]

extension TaskAnalyticsAPI {
    /// GET `/TaskAnalytics/tasks/completion`
    func getTaskCompletionAnalytics(_ request: TaskCompletionAnalyticsRequestDTO) async throws -> TaskCompletionAnalyticsResponseDTO {
        try await client.request(
            .get,
            path: "TaskAnalytics/tasks/completion",
            query: [
                "userId": request.userId,
                "days": request.days.map(String.init),
                "project": request.project,
                "category": request.category
            ],
            headers: [:],
            body: nil
        )
    }

    /// GET `/TaskAnalytics/subtasks/completion`
    func getSubTaskCompletionAnalytics(_ request: SubTaskCompletionAnalyticsRequestDTO) async throws -> SubTaskCompletionAnalyticsResponseDTO {
        try await client.request(
            .get,
            path: "TaskAnalytics/subtasks/completion",
            query: [
                "userId": request.userId,
                "days": request.days.map(String.init),
                "taskId": request.taskId
            ],
            headers: [:],
            body: nil
        )
    }

    /// GET `/TaskAnalytics/task/{taskId}?userId=...`
    func getTaskDetailAnalytics(taskId: String, userId: String) async throws -> TaskDetailedAnalyticsResponseDTO {
        try await client.request(
            .get,
            path: "TaskAnalytics/task/\(taskId)",
            query: ["userId": userId],
            headers: [:],
            body: nil
        )
    }
}

