import Foundation

// MARK: - Plaid API

struct PlaidAPI: Sendable {
    let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }
}

// MARK: - Connected Account DTOs

struct ConnectedAccountDTO: Codable, Sendable, Identifiable {
    let id: Int
    let institutionName: String
    let connectedAt: String
    let lastSyncedAt: String?
    let isActive: Bool
    let errorMessage: String?
    let totalBalance: Double
    let accounts: [SubAccountDTO]?
}

struct SubAccountDTO: Codable, Sendable, Identifiable {
    var id: String { accountId ?? UUID().uuidString }
    let accountId: String?
    let accountName: String?
    let name: String?
    let lastFourDigits: String?
    let balance: Double?
    let currentBalance: Double?
    let availableBalance: Double?
    let accountType: String?
    let subtype: String?
}

struct ConnectedAccountsResponseDTO: Codable, Sendable {
    let accounts: [ConnectedAccountDTO]
}

// MARK: - Balance Trends DTOs

struct BalanceTrendsResponseDTO: Codable, Sendable {
    let success: Bool
    let message: String
    let timestamp: String
    let data: BalanceTrendsDataDTO?
}

struct BalanceTrendsDataDTO: Codable, Sendable {
    let totalSnapshots: Int
    let dateRange: DateRangeDTO
    let summary: TrendsSummaryDTO?
    let snapshots: [DailySnapshotDTO]
    let byAccountType: [AccountTypeTrendDTO]?
    let byAccount: [IndividualAccountTrendDTO]?
}

struct DateRangeDTO: Codable, Sendable {
    let start: String
    let end: String
}

struct TrendsSummaryDTO: Codable, Sendable {
    let currentBalance: Double
    let startingBalance: Double
    let netChange: Double
    let netChangePercent: Double
    let highestBalance: Double
    let highestBalanceDate: String?
    let lowestBalance: Double
    let lowestBalanceDate: String?
    let averageBalance: Double
    let averageDailyChange: Double
    let positiveDays: Int
    let negativeDays: Int
    let unchangedDays: Int
}

struct DailySnapshotDTO: Codable, Sendable, Identifiable {
    var id: String { date }
    let date: String
    let totalBalance: Double
    let totalAvailableBalance: Double?
    let checkingBalance: Double?
    let savingsBalance: Double?
    let creditCardBalance: Double?
    let investmentBalance: Double?
    let loanBalance: Double?
    let otherBalance: Double?
    let dailyChange: Double?
    let dailyChangePercent: Double?
    let accountCount: Int
}

struct AccountTypeTrendDTO: Codable, Sendable, Identifiable {
    var id: String { accountType }
    let accountType: String
    let currentBalance: Double
    let startingBalance: Double
    let netChange: Double
    let netChangePercent: Double
    let dataPoints: [DataPointDTO]
}

struct IndividualAccountTrendDTO: Codable, Sendable, Identifiable {
    var id: String { accountId }
    let accountId: String
    let accountName: String
    let accountMask: String?
    let accountType: String?
    let accountSubtype: String?
    let institutionName: String?
    let currentBalance: Double
    let startingBalance: Double
    let netChange: Double
    let netChangePercent: Double
    let dataPoints: [DataPointDTO]
}

struct DataPointDTO: Codable, Sendable, Identifiable {
    var id: String { date }
    let date: String
    let balance: Double
}

// MARK: - Refresh Response DTOs

struct RefreshBalancesResponseDTO: Codable, Sendable {
    let success: Bool
    let message: String
    let summary: RefreshSummaryDTO?
    let timestamp: String
}

struct RefreshSummaryDTO: Codable, Sendable {
    let totalAccounts: Int
    let successfulAccounts: Int
    let failedAccounts: Int
    let balancesRecorded: Int
}

// MARK: - Link Token DTOs

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

struct SyncTransactionsResponseDTO: Codable, Sendable {
    let success: Bool
    let message: String
    let newTransactionsCount: Int
    let recurringDetectedCount: Int?
}

struct DisconnectResponseDTO: Codable, Sendable {
    let success: Bool
    let message: String
}

// MARK: - API Methods

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
    func getConnectedAccounts(userId: String) async throws -> ConnectedAccountsResponseDTO {
        try await client.request(.get, path: "plaid/connected-accounts/\(userId)", query: [:], headers: [:], body: nil)
    }

    /// POST `/plaid/sync-transactions/{connectedAccountId}`
    func syncTransactions(connectedAccountId: Int, startDate: String? = nil, endDate: String? = nil, detectRecurring: Bool? = nil) async throws -> SyncTransactionsResponseDTO {
        try await client.request(
            .post,
            path: "plaid/sync-transactions/\(connectedAccountId)",
            query: ["startDate": startDate, "endDate": endDate, "detectRecurring": detectRecurring.map(String.init)],
            headers: [:],
            body: JSONValue.object([:])
        )
    }

    /// DELETE `/plaid/disconnect/{connectedAccountId}?userId=...`
    func disconnectAccount(connectedAccountId: Int, userId: String) async throws -> DisconnectResponseDTO {
        try await client.request(.delete, path: "plaid/disconnect/\(connectedAccountId)", query: ["userId": userId], headers: [:], body: nil)
    }

    /// POST `/plaid/reauth-link-token`
    func createReauthLinkToken(connectedAccountId: Int, userId: String) async throws -> PlaidLinkTokenResponseDTO {
        struct Body: Codable { let userId: String; let connectedAccountId: Int }
        return try await client.request(.post, path: "plaid/reauth-link-token", query: [:], headers: [:], body: Body(userId: userId, connectedAccountId: connectedAccountId))
    }

    /// POST `/plaid/reauth-complete/{connectedAccountId}`
    func completeReauth(connectedAccountId: Int, userId: String) async throws -> DisconnectResponseDTO {
        try await client.request(.post, path: "plaid/reauth-complete/\(connectedAccountId)", query: ["userId": userId], headers: [:], body: JSONValue.object([:]))
    }
}

// MARK: - Balance API Methods

extension PlaidAPI {
    /// GET `/balances?userId=...&type=trends&startDate=...&endDate=...`
    func getBalanceTrends(userId: String, startDate: String? = nil, endDate: String? = nil) async throws -> BalanceTrendsResponseDTO {
        var query: [String: String?] = ["userId": userId, "type": "trends"]
        if let startDate { query["startDate"] = startDate }
        if let endDate { query["endDate"] = endDate }
        return try await client.request(.get, path: "balances", query: query, headers: [:], body: nil)
    }

    /// POST `/balances/refresh?userId=...`
    func refreshBalances(userId: String) async throws -> RefreshBalancesResponseDTO {
        try await client.request(.post, path: "balances/refresh", query: ["userId": userId], headers: [:], body: JSONValue.object([:]))
    }

    /// POST `/plaid/sync-balances/{connectedAccountId}?userId=...`
    func syncAccountBalances(connectedAccountId: Int, userId: String) async throws -> RefreshBalancesResponseDTO {
        try await client.request(.post, path: "plaid/sync-balances/\(connectedAccountId)", query: ["userId": userId], headers: [:], body: JSONValue.object([:]))
    }
}
