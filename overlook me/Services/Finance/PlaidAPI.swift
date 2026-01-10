import Foundation

struct PlaidAPI: Sendable {
    let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }
}

struct PlaidLinkTokenResponseDTO: Codable, Sendable {
    let linkToken: String
    let expiresAt: String
}

struct PlaidExchangeTokenRequestDTO: Codable, Sendable {
    let publicToken: String
    let userId: String
    let institutionName: String?
}

struct PlaidExchangeTokenResponseDTO: Codable, Sendable {
    let success: Bool
    let message: String
    let connectedAccountId: Int
}

typealias ConnectedAccountDTO = [String: JSONValue]
typealias PlaidTransactionsResponseDTO = [String: JSONValue]
typealias SyncTransactionsResponseDTO = [String: JSONValue]

extension PlaidAPI {
    /// POST `/plaid/create-link-token`
    func createLinkToken(userId: String) async throws -> PlaidLinkTokenResponseDTO {
        struct Body: Codable { let userId: String }
        return try await client.request(.post, path: "plaid/create-link-token", query: [:], headers: [:], body: Body(userId: userId))
    }

    /// POST `/plaid/exchange-token`
    func exchangePublicToken(_ request: PlaidExchangeTokenRequestDTO) async throws -> PlaidExchangeTokenResponseDTO {
        try await client.request(.post, path: "plaid/exchange-token", query: [:], headers: [:], body: request)
    }

    /// GET `/plaid/connected-accounts/{userId}`
    func getConnectedAccounts(userId: String) async throws -> [String: [ConnectedAccountDTO]] {
        try await client.request(.get, path: "plaid/connected-accounts/\(userId)", query: [:], headers: [:], body: nil)
    }

    /// POST `/plaid/sync-transactions/{connectedAccountId}?startDate=...&endDate=...&detectRecurring=...`
    func syncTransactions(connectedAccountId: Int, startDate: String? = nil, endDate: String? = nil, detectRecurring: Bool? = nil) async throws -> SyncTransactionsResponseDTO {
        try await client.request(
            .post,
            path: "plaid/sync-transactions/\(connectedAccountId)",
            query: ["startDate": startDate, "endDate": endDate, "detectRecurring": detectRecurring.map(String.init)],
            headers: [:],
            body: JSONValue.object([:])
        )
    }

    /// GET `/plaid/transactions/{userId}?startDate=...&endDate=...`
    func getTransactions(userId: String, startDate: String? = nil, endDate: String? = nil) async throws -> PlaidTransactionsResponseDTO {
        try await client.request(
            .get,
            path: "plaid/transactions/\(userId)",
            query: ["startDate": startDate, "endDate": endDate],
            headers: [:],
            body: nil
        )
    }

    /// DELETE `/plaid/disconnect/{connectedAccountId}?userId=...`
    func disconnectAccount(connectedAccountId: Int, userId: String) async throws -> [String: JSONValue] {
        try await client.request(.delete, path: "plaid/disconnect/\(connectedAccountId)", query: ["userId": userId], headers: [:], body: nil)
    }

    /// GET `/plaid/webhook-status`
    func getWebhookStatus() async throws -> JSONValue {
        try await client.request(.get, path: "plaid/webhook-status", query: [:], headers: [:], body: nil)
    }

    /// POST `/plaid/update-webhook/{connectedAccountId}`
    func updateWebhook(connectedAccountId: Int) async throws -> [String: JSONValue] {
        try await client.request(.post, path: "plaid/update-webhook/\(connectedAccountId)", query: [:], headers: [:], body: JSONValue.object([:]))
    }

    /// GET `/plaid/debug/{userId}`
    func debugUserData(userId: String) async throws -> JSONValue {
        try await client.request(.get, path: "plaid/debug/\(userId)", query: [:], headers: [:], body: nil)
    }
}

