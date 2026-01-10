import Foundation

struct AIInsightsAPI: Sendable {
    let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }
}

struct UserInsightDTO: Codable, Sendable, Identifiable {
    let id: String
    let type: String?
    let title: String?
    let message: String?
    let priority: String?
    let actionItems: [String]?
    let metrics: [String: JSONValue]?
    let generatedAt: String?
    let expiresAt: String?
    let isRead: Bool?
}

struct DailyInsightsResponseDTO: Codable, Sendable {
    let insights: [UserInsightDTO]
    let generatedAt: String
    let nextGenerationAt: String
}

struct InsightHistoryParamsDTO: Codable, Sendable {
    let userId: String
    let days: Int?
    let insightType: String?
}

struct RegenerateInsightRequestDTO: Codable, Sendable {
    let userId: String
    let insightTypes: [String]
}

struct RegenerateInsightResponseDTO: Codable, Sendable {
    let message: String
    let jobId: String
    let estimatedCompletion: String
}

extension AIInsightsAPI {
    private var basePath: String { "api/AIInsights" }

    func getDailyInsights(userId: String, insightType: String? = nil) async throws -> DailyInsightsResponseDTO {
        try await client.request(
            .get,
            path: "\(basePath)/daily",
            query: ["userId": userId, "insightType": insightType],
            headers: [:],
            body: nil
        )
    }

    func getInsightHistory(_ params: InsightHistoryParamsDTO) async throws -> [UserInsightDTO] {
        try await client.request(
            .get,
            path: "\(basePath)/history",
            query: [
                "userId": params.userId,
                "days": params.days.map(String.init),
                "insightType": params.insightType
            ],
            headers: [:],
            body: nil
        )
    }

    func regenerateInsights(_ request: RegenerateInsightRequestDTO) async throws -> RegenerateInsightResponseDTO {
        try await client.request(.post, path: "\(basePath)/regenerate", query: [:], headers: [:], body: request)
    }

    func markInsightAsRead(insightId: String, userId: String) async throws -> EmptyResponse {
        struct Body: Codable { let userId: String }
        return try await client.request(.patch, path: "\(basePath)/\(insightId)/read", query: [:], headers: [:], body: Body(userId: userId))
    }
}

