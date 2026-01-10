import Foundation

struct TransactionsAPI: Sendable {
    let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }
}

struct TransactionDTO: Codable, Sendable {
    let id: Int
    let transactionId: String?
    let connectedAccountId: Int?
    let accountId: String?
    let amount: Double
    let isoCurrencyCode: String?
    let date: String
    let name: String?
    let merchantName: String?
    let category: String?
    let userId: String
    let customCategoryId: Int?
    let notes: String?
    let isExcludedFromBudget: Bool?
    let recurringTransactionId: Int?
    let isPending: Bool?
    let createdAt: String?
    let updatedAt: String?
}

typealias LargestTransactionsResponseDTO = [String: JSONValue]
typealias SpendingAnalysisResponseDTO = [String: JSONValue]
typealias CategorySuggestionDTO = [String: JSONValue]

struct CategorizeTransactionRequestDTO: Codable, Sendable {
    let userId: String
    let subcategoryId: Int
}

struct BulkCategorizeRequestDTO: Codable, Sendable {
    let userId: String
    let transactionIds: [Int]
    let subcategoryId: Int
}

struct AddTagsRequestDTO: Codable, Sendable {
    let userId: String
    let tagNames: [String]
}

struct UpdateNotesRequestDTO: Codable, Sendable {
    let userId: String
    let notes: String
}

extension TransactionsAPI {
    /// GET `/transactions` (unified endpoint; returns varying shapes depending on `type`)
    func getTransactions(query: [String: String?]) async throws -> JSONValue {
        try await client.request(.get, path: "transactions", query: query, headers: [:], body: nil)
    }

    /// PUT `/transactions/{transactionId}/categorize`
    func categorizeTransaction(transactionId: Int, request: CategorizeTransactionRequestDTO) async throws -> JSONValue {
        try await client.request(.put, path: "transactions/\(transactionId)/categorize", query: [:], headers: [:], body: request)
    }

    /// POST `/transactions/bulk-categorize`
    func bulkCategorize(_ request: BulkCategorizeRequestDTO) async throws -> JSONValue {
        try await client.request(.post, path: "transactions/bulk-categorize", query: [:], headers: [:], body: request)
    }

    /// GET `/transactions/{transactionId}/suggestions?userId=...`
    func getSuggestionsForTransaction(transactionId: Int, userId: String) async throws -> [CategorySuggestionDTO] {
        try await client.request(
            .get,
            path: "transactions/\(transactionId)/suggestions",
            query: ["userId": userId],
            headers: [:],
            body: nil
        )
    }

    /// POST `/transactions/recategorize-all`
    func recategorizeAll(userId: String) async throws -> JSONValue {
        struct Body: Codable { let userId: String }
        return try await client.request(.post, path: "transactions/recategorize-all", query: [:], headers: [:], body: Body(userId: userId))
    }

    /// POST `/transactions/{transactionId}/tags`
    func addTags(transactionId: Int, request: AddTagsRequestDTO) async throws -> JSONValue {
        try await client.request(.post, path: "transactions/\(transactionId)/tags", query: [:], headers: [:], body: request)
    }

    /// PUT `/transactions/{transactionId}/notes`
    func updateNotes(transactionId: Int, request: UpdateNotesRequestDTO) async throws -> JSONValue {
        try await client.request(.put, path: "transactions/\(transactionId)/notes", query: [:], headers: [:], body: request)
    }
}

