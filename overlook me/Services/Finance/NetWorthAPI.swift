import Foundation

struct NetWorthAPI: Sendable {
    let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }
}

typealias AssetDTO = [String: JSONValue]
typealias LiabilityDTO = [String: JSONValue]
typealias NetWorthSummaryDTO = [String: JSONValue]
typealias NetWorthSnapshotDTO = [String: JSONValue]
typealias NetWorthTrendDTO = [String: JSONValue]
typealias AssetAllocationResponseDTO = [String: JSONValue]
typealias LiabilityBreakdownResponseDTO = [String: JSONValue]
typealias DebtRatioResponseDTO = [String: JSONValue]

struct CreateAssetRequestDTO: Codable, Sendable {
    let userId: String
    let name: String
    let assetType: String
    let category: String?
    let currentValue: Double
    let currency: String?
    let connectedAccountId: Int?
    let isAutoUpdated: Bool?
    let purchasePrice: Double?
    let purchaseDate: String?
    let description: String?
    let notes: String?
    let isActive: Bool?
}

struct CreateLiabilityRequestDTO: Codable, Sendable {
    let userId: String
    let name: String
    let liabilityType: String
    let currentBalance: Double
    let originalAmount: Double?
    let currency: String?
    let interestRate: Double?
    let minimumPayment: Double?
    let monthlyPayment: Double?
    let startDate: String?
    let maturityDate: String?
    let nextPaymentDate: String?
    let lender: String?
    let accountNumber: String?
    let description: String?
    let notes: String?
    let isActive: Bool?
}

extension NetWorthAPI {
    /// GET `/networth` (unified endpoint; varies by `type`)
    func getNetWorth(query: [String: String?]) async throws -> JSONValue {
        try await client.request(.get, path: "networth", query: query, headers: [:], body: nil)
    }

    /// GET `/networth/assets` (unified endpoint; varies by `type`)
    func getAssets(query: [String: String?]) async throws -> JSONValue {
        try await client.request(.get, path: "networth/assets", query: query, headers: [:], body: nil)
    }

    /// POST `/networth/assets`
    func createAsset(_ request: CreateAssetRequestDTO) async throws -> AssetDTO {
        try await client.request(.post, path: "networth/assets", query: [:], headers: [:], body: request)
    }

    /// PUT `/networth/assets/{assetId}/user/{userId}`
    func updateAsset(assetId: Int, userId: String, asset: [String: JSONValue]) async throws -> AssetDTO {
        try await client.request(.put, path: "networth/assets/\(assetId)/user/\(userId)", query: [:], headers: [:], body: asset)
    }

    /// DELETE `/networth/assets/{assetId}/user/{userId}`
    func deleteAsset(assetId: Int, userId: String) async throws -> [String: JSONValue] {
        try await client.request(.delete, path: "networth/assets/\(assetId)/user/\(userId)", query: [:], headers: [:], body: nil)
    }

    /// GET `/networth/liabilities` (unified endpoint; varies by `type`)
    func getLiabilities(query: [String: String?]) async throws -> JSONValue {
        try await client.request(.get, path: "networth/liabilities", query: query, headers: [:], body: nil)
    }

    /// POST `/networth/liabilities`
    func createLiability(_ request: CreateLiabilityRequestDTO) async throws -> LiabilityDTO {
        try await client.request(.post, path: "networth/liabilities", query: [:], headers: [:], body: request)
    }

    /// PUT `/networth/liabilities/{liabilityId}/user/{userId}`
    func updateLiability(liabilityId: Int, userId: String, liability: [String: JSONValue]) async throws -> LiabilityDTO {
        try await client.request(.put, path: "networth/liabilities/\(liabilityId)/user/\(userId)", query: [:], headers: [:], body: liability)
    }

    /// DELETE `/networth/liabilities/{liabilityId}/user/{userId}`
    func deleteLiability(liabilityId: Int, userId: String) async throws -> [String: JSONValue] {
        try await client.request(.delete, path: "networth/liabilities/\(liabilityId)/user/\(userId)", query: [:], headers: [:], body: nil)
    }

    /// POST `/networth/snapshot/{userId}?snapshotType=...`
    func createSnapshot(userId: String, snapshotType: String = "Manual") async throws -> NetWorthSnapshotDTO {
        try await client.request(
            .post,
            path: "networth/snapshot/\(userId)",
            query: ["snapshotType": snapshotType],
            headers: [:],
            body: JSONValue.object([:])
        )
    }

    /// GET `/networth/analytics` (unified endpoint; varies by `type`)
    func getAnalytics(query: [String: String?]) async throws -> JSONValue {
        try await client.request(.get, path: "networth/analytics", query: query, headers: [:], body: nil)
    }
}

