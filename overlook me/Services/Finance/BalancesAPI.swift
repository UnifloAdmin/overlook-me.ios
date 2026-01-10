import Foundation

struct BalancesAPI: Sendable {
    let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }
}

struct BalanceDTO: Codable, Sendable {
    let accountId: String
    let accountName: String
    let institutionName: String
    let accountType: String
    let currentBalance: Double
    let availableBalance: Double?
    let currency: String
    let lastUpdated: String
    let isActive: Bool
}

typealias LatestBalancesResponseDTO = [String: JSONValue]
typealias BalanceHistoryResponseDTO = [String: JSONValue]

extension BalancesAPI {
    /// GET `/balances` (unified endpoint; response varies by `type`)
    func getBalances(query: [String: String?]) async throws -> JSONValue {
        try await client.request(.get, path: "balances", query: query, headers: [:], body: nil)
    }

    /// POST `/balances/refresh?userId=...`
    func refreshBalances(userId: String) async throws -> [String: JSONValue] {
        try await client.request(.post, path: "balances/refresh", query: ["userId": userId], headers: [:], body: JSONValue.object([:]))
    }
}

