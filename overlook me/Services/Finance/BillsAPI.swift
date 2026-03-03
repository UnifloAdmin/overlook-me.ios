import Foundation

struct BillsAPI: Sendable {
    let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }
}

// MARK: - DTOs

struct BillDTO: Codable, Sendable, Identifiable {
    let id: Int
    let merchantName: String
    let amount: Double
    let frequency: String
    let nextExpectedDate: String?
    let isSubscription: Bool
    let daysUntilDue: Int
    let isOverdue: Bool
    let categoryName: String?
    let isConfirmedByUser: Bool
    let billType: String?
}

struct UpcomingBillsResponseDTO: Codable, Sendable {
    let bills: [BillDTO]
    let count: Int
    let totalDue: Double
    let periodDays: Int
}

struct BillsSummaryDTO: Codable, Sendable {
    let totalBills: Int
    let dueThisMonth: Int
    let dueThisMonthAmount: Double
    let overdueCount: Int
    let overdueAmount: Double
    let estimatedMonthlyTotal: Double
}

// MARK: - Endpoints

extension BillsAPI {
    func getUpcomingBills(userId: String, days: Int = 28) async throws -> UpcomingBillsResponseDTO {
        try await client.request(
            .get,
            path: "bills/upcoming",
            query: ["userId": userId, "days": String(days)],
            headers: [:],
            body: nil
        )
    }

    func getBillsSummary(userId: String) async throws -> BillsSummaryDTO {
        try await client.request(
            .get,
            path: "bills/summary",
            query: ["userId": userId],
            headers: [:],
            body: nil
        )
    }
}
