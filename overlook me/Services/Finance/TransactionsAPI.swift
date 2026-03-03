import Foundation

struct TransactionsAPI: Sendable {
    let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }
}

// MARK: - Transaction DTO

struct TransactionDTO: Codable, Sendable, Identifiable {
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
    let userId: String?
    let customCategoryId: Int?
    let notes: String?
    let isExcludedFromBudget: Bool?
    let recurringTransactionId: Int?
    let isPending: Bool?
    let createdAt: String?
    let updatedAt: String?
    
    var isExpense: Bool { amount > 0 }
    var isIncome: Bool { amount < 0 }
    var displayAmount: Double { abs(amount) }
}

// MARK: - Transactions Response DTO

struct TransactionsResponseDTO: Codable, Sendable {
    let transactions: [TransactionDTO]?
    let totalCount: Int?
    let totalSpent: Double?
    let totalIncome: Double?
    let expenseCount: Int?
    let incomeCount: Int?
    let pagination: PaginationDTO?
}

struct PaginationDTO: Codable, Sendable {
    let currentPage: Int?
    let pageSize: Int?
    let totalItems: Int?
    let totalPages: Int?
    let hasPrevious: Bool?
    let hasNext: Bool?
}

// MARK: - Spending Analysis Response DTO

struct SpendingAnalysisResponseDTO: Codable, Sendable {
    let period: String?
    let startDate: String?
    let endDate: String?
    let totalSpent: Double?
    let totalIncome: Double?
    let totalTransactions: Int?
    let averageDailySpending: Double?
    let highestSpendingDay: String?
    let topCategories: [CategorySpendingDetailDTO]?
    let spendingInsights: [String]?
    let dailyBreakdown: [DailySpendingDTO]?
    let dayOfWeekBreakdown: [DayOfWeekSpendingDTO]?
    let periodComparison: PeriodComparisonDTO?
    let timeOfDayAnalysis: TimeOfDayAnalysisDTO?
}

struct CategorySpendingDetailDTO: Codable, Sendable, Identifiable {
    var id: String { categoryName }
    let categoryName: String
    let totalAmount: Double
    let transactionCount: Int
    let averageTransactionAmount: Double?
    let percentage: Double
    let topMerchants: [MerchantSpendingDTO]?
}

struct MerchantSpendingDTO: Codable, Sendable, Identifiable {
    var id: String { merchantName }
    let merchantName: String
    let totalAmount: Double
    let transactionCount: Int
}

struct DailySpendingDTO: Codable, Sendable, Identifiable {
    var id: String { date }
    let date: String
    let spending: Double
    let income: Double?
    let transactionCount: Int?
    
    // Custom decoding to handle date as ISO 8601 DateTime string
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        spending = try container.decode(Double.self, forKey: .spending)
        income = try container.decodeIfPresent(Double.self, forKey: .income)
        transactionCount = try container.decodeIfPresent(Int.self, forKey: .transactionCount)
        
        // Handle date which comes as ISO 8601 DateTime string from .NET
        if let dateString = try? container.decode(String.self, forKey: .date) {
            // Extract just the date portion if it includes time
            date = String(dateString.prefix(10))
        } else {
            date = "unknown"
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case date, spending, income, transactionCount
    }
}

struct DayOfWeekSpendingDTO: Codable, Sendable, Identifiable {
    var id: Int { dayOfWeek }
    let day: String
    let dayOfWeek: Int
    let date: String?
    let spending: Double
    let transactions: Int?
    
    // Custom decoding to handle date as either String or Date object
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        day = try container.decode(String.self, forKey: .day)
        dayOfWeek = try container.decode(Int.self, forKey: .dayOfWeek)
        spending = try container.decode(Double.self, forKey: .spending)
        transactions = try container.decodeIfPresent(Int.self, forKey: .transactions)
        
        // Handle date which may come as ISO string from DateTime
        if let dateString = try? container.decodeIfPresent(String.self, forKey: .date) {
            date = dateString
        } else {
            date = nil
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case day, dayOfWeek, date, spending, transactions
    }
}

struct PeriodComparisonDTO: Codable, Sendable {
    let current: PeriodMetricsDTO
    let previous: PeriodMetricsDTO
    let changes: PeriodChangesDTO
}

struct PeriodMetricsDTO: Codable, Sendable {
    let spending: Double
    let income: Double
    let netFlow: Double
}

struct PeriodChangesDTO: Codable, Sendable {
    let spending: ChangeMetricDTO
    let income: ChangeMetricDTO
    let netFlow: ChangeMetricDTO
}

struct ChangeMetricDTO: Codable, Sendable {
    let percentage: Double
    let isIncrease: Bool
}

struct TimeOfDayAnalysisDTO: Codable, Sendable {
    let morning: TimeSlotDTO
    let afternoon: TimeSlotDTO
    let evening: TimeSlotDTO
    let night: TimeSlotDTO
    let peakSpendingTime: String?
    let totalAnalyzed: Double?
}

struct TimeSlotDTO: Codable, Sendable {
    let label: String?
    let timeRange: String?
    let totalSpending: Double
    let transactionCount: Int
    let percentage: Double
    let averageTransaction: Double?
}

// MARK: - Legacy type aliases for compatibility

typealias LargestTransactionsResponseDTO = [String: JSONValue]
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
    
    /// GET `/transactions?type=all` - Paginated transactions
    func getAllTransactions(
        userId: String,
        page: Int = 1,
        pageSize: Int = 20,
        startDate: String? = nil,
        endDate: String? = nil,
        search: String? = nil,
        sortBy: String = "date",
        sortOrder: String = "desc"
    ) async throws -> TransactionsResponseDTO {
        var query: [String: String?] = [
            "userId": userId,
            "type": "all",
            "page": String(page),
            "pageSize": String(pageSize),
            "sortBy": sortBy,
            "sortOrder": sortOrder
        ]
        if let startDate { query["startDate"] = startDate }
        if let endDate { query["endDate"] = endDate }
        if let search, !search.isEmpty { query["search"] = search }
        return try await client.request(.get, path: "transactions", query: query, headers: [:], body: nil)
    }
    
    /// GET `/transactions?type=analysis` - Spending analysis with charts data
    func getSpendingAnalysis(
        userId: String,
        startDate: String? = nil,
        endDate: String? = nil
    ) async throws -> SpendingAnalysisResponseDTO {
        var query: [String: String?] = [
            "userId": userId,
            "type": "analysis"
        ]
        if let startDate { query["startDate"] = startDate }
        if let endDate { query["endDate"] = endDate }
        return try await client.request(.get, path: "transactions", query: query, headers: [:], body: nil)
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

