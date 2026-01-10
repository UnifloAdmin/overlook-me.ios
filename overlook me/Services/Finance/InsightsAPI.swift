import Foundation

struct InsightsAPI: Sendable {
    let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }
}

typealias SpendingTrendDTO = [String: JSONValue]
typealias CategoryTrendDTO = [String: JSONValue]
typealias SpendingAnomalyDTO = [String: JSONValue]
typealias TopMerchantDTO = [String: JSONValue]
typealias SpendingPatternDTO = [String: JSONValue]
typealias DetectPatternsResponseDTO = [String: JSONValue]
typealias FinancialHealthScoreDTO = [String: JSONValue]
typealias YearOverYearComparisonDTO = [String: JSONValue]
typealias CalculateBaselinesResponseDTO = [String: JSONValue]

extension InsightsAPI {
    /// GET `/insights` (unified endpoint; varies by `type`)
    func getInsights(query: [String: String?]) async throws -> JSONValue {
        try await client.request(.get, path: "insights", query: query, headers: [:], body: nil)
    }

    /// POST `/insights/patterns/detect?userId=...`
    func detectSpendingPatterns(userId: String) async throws -> DetectPatternsResponseDTO {
        try await client.request(.post, path: "insights/patterns/detect", query: ["userId": userId], headers: [:], body: JSONValue.object([:]))
    }

    /// POST `/insights/health-score/calculate?userId=...`
    func calculateHealthScore(userId: String) async throws -> FinancialHealthScoreDTO {
        try await client.request(.post, path: "insights/health-score/calculate", query: ["userId": userId], headers: [:], body: JSONValue.object([:]))
    }

    /// POST `/insights/baselines/calculate?userId=...`
    func calculateBaselines(userId: String) async throws -> CalculateBaselinesResponseDTO {
        try await client.request(.post, path: "insights/baselines/calculate", query: ["userId": userId], headers: [:], body: JSONValue.object([:]))
    }
}

