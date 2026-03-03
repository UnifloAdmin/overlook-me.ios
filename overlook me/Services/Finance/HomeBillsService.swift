import Foundation
import Combine

// MARK: - Domain Models

struct WeekBucket: Identifiable {
    let id: Int
    let label: String
    var total: Double
    var count: Int
}

// MARK: - State

struct HomeBillsState {
    var bills: [BillDTO]
    var summary: BillsSummaryDTO?
    var isLoading: Bool
    var failed: Bool

    static let loading = HomeBillsState(bills: [], summary: nil, isLoading: true, failed: false)

    var weekBuckets: [WeekBucket] {
        let cal = Calendar.current
        let now = Date()
        let startOfWeek = cal.date(
            from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        ) ?? now

        var buckets = [
            WeekBucket(id: 0, label: "This week",  total: 0, count: 0),
            WeekBucket(id: 1, label: "Next week",  total: 0, count: 0),
            WeekBucket(id: 2, label: "In 2 weeks", total: 0, count: 0),
            WeekBucket(id: 3, label: "In 3 weeks", total: 0, count: 0)
        ]

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let simple = DateFormatter()
        simple.dateFormat = "yyyy-MM-dd"

        for bill in bills {
            guard let raw = bill.nextExpectedDate else { continue }
            let due = iso.date(from: raw) ?? simple.date(from: String(raw.prefix(10)))
            guard let due else { continue }
            let diff = cal.dateComponents([.day], from: startOfWeek, to: due).day ?? 0
            let idx = diff / 7
            guard idx >= 0 && idx < 4 else { continue }
            buckets[idx].total += bill.amount
            buckets[idx].count += 1
        }
        return buckets
    }

    var overdueBills: [BillDTO]  { bills.filter { $0.isOverdue } }
    var overdueTotal: Double     { overdueBills.reduce(0) { $0 + $1.amount } }
    var dueSoonCount: Int        { bills.filter { $0.daysUntilDue >= 0 && $0.daysUntilDue <= 3 }.count }
    var totalUpcoming: Double    { weekBuckets.reduce(0) { $0 + $1.total } }
    var maxWeekTotal: Double     { weekBuckets.map(\.total).max() ?? 1 }
    var estimatedMonthly: Double { summary?.estimatedMonthlyTotal ?? 0 }

    var summaryHeadline: String {
        let overdue = overdueBills.count
        let soon    = dueSoonCount
        let amount  = totalUpcoming
        if overdue >= 3  { return "A few bills slipped through — let's catch up together" }
        if overdue > 0   { return "You have something overdue — a quick check will sort it out" }
        if soon >= 3     { return "Busy week ahead — a few bills are lining up soon" }
        if soon > 0      { return "Something's due shortly — just a gentle heads up" }
        if bills.isEmpty { return "All clear — nothing due right now, enjoy the calm" }
        if amount > 500  { return "A bigger month ahead — plan accordingly" }
        return "You're all caught up — smooth sailing ahead"
    }

    var weekHint: String {
        let active = weekBuckets.filter { $0.count > 0 }
        guard let heaviest = active.max(by: { $0.total < $1.total }),
              heaviest.total > 0 else { return "" }
        return "\(heaviest.label) is your heaviest — plan accordingly"
    }
}

// MARK: - Service

@MainActor
final class HomeBillsService: ObservableObject {
    @Published private(set) var state: HomeBillsState = .loading

    private let api = BillsAPI(client: LoggingAPIClient(base: AppAPIClient.live()))
    private var loadedUserId: String?

    func load(userId: String) async {
        guard userId != loadedUserId || state.failed else { return }
        loadedUserId = userId
        state = .loading

        async let upcomingCall = api.getUpcomingBills(userId: userId, days: 28)
        async let summaryCall  = api.getBillsSummary(userId: userId)

        do {
            let (upcoming, summary) = try await (upcomingCall, summaryCall)
            state = HomeBillsState(
                bills: upcoming.bills,
                summary: summary,
                isLoading: false,
                failed: false
            )
        } catch {
            state = HomeBillsState(bills: [], summary: nil, isLoading: false, failed: true)
        }
    }

    func refresh(userId: String) async {
        loadedUserId = nil
        await load(userId: userId)
    }
}
