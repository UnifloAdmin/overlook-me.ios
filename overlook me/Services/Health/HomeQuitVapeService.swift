import Foundation
import Combine

// MARK: - State

struct HomeQuitVapeState {
    var dashboard: QuitVapeDashboardDTO?
    var recentCravings: [VapeCravingLogDTO]
    var isLoading: Bool
    var failed: Bool
    var hasProfile: Bool

    static let loading = HomeQuitVapeState(
        dashboard: nil, recentCravings: [], isLoading: true, failed: false, hasProfile: false
    )

    // ── Computed ──

    var daysQuit: Int { dashboard?.daysQuit ?? 0 }
    var totalPuffs: Int {
        recentCravings.reduce(0) { $0 + $1.puffCount }
    }
    var totalCravings: Int { dashboard?.totalCravings ?? 0 }
    var resistRate: Int { Int(dashboard?.resistRate ?? 0) }
    var currentStreak: Int { dashboard?.profile.currentStreakDays ?? 0 }
    var longestStreak: Int { dashboard?.profile.longestStreakDays ?? 0 }
    var resistedCount: Int { dashboard?.profile.totalCravingsResisted ?? 0 }
    var givenInCount: Int { dashboard?.profile.totalCravingsGivenIn ?? 0 }

    var puffsToday: Int {
        let today = todayKey
        return recentCravings
            .filter { $0.occurredAt.hasPrefix(today) }
            .reduce(0) { $0 + $1.puffCount }
    }

    var todayCravingCount: Int {
        let today = todayKey
        return recentCravings.filter { $0.occurredAt.hasPrefix(today) }.count
    }

    private var todayKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    /// Last 7 days puff counts for the mini bar chart (oldest → today)
    var last7DaysPuffs: [(label: String, puffs: Int)] {
        let dayNames = Calendar.current.shortWeekdaySymbols
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return (0..<7).map { i -> (String, Int) in
            let offset = i - 6          // -6, -5, -4, … 0
            let d = Calendar.current.date(byAdding: .day, value: offset, to: Date())!
            let key = f.string(from: d)
            let puffs = recentCravings
                .filter { $0.occurredAt.hasPrefix(key) }
                .reduce(0) { $0 + $1.puffCount }
            let day = Calendar.current.component(.weekday, from: d)
            return (dayNames[day - 1], puffs)
        }
    }

    var headline: String {
        guard hasProfile else { return "Start tracking to see your progress" }
        let streak = currentStreak
        let rate = resistRate
        if streak >= 7 && rate >= 80 { return "Incredible — \(streak)-day streak and \(rate)% resist rate" }
        if streak >= 3 { return "\(streak)-day streak going strong 💪" }
        if rate >= 70 { return "Great resist rate — keep it up" }
        if puffsToday == 0 && todayCravingCount == 0 { return "Clean day so far — stay strong" }
        if puffsToday > 0 { return "\(puffsToday) puffs today — every fewer counts" }
        return "Track cravings to build awareness"
    }
}

// MARK: - Service

@MainActor
final class HomeQuitVapeService: ObservableObject {
    @Published private(set) var state: HomeQuitVapeState = .loading

    private let api = QuitVapeAPI(client: AppAPIClient.live())
    private var loadedUserId: String?

    func load(userId: String) async {
        guard userId != loadedUserId || state.failed else { return }
        loadedUserId = userId
        state = .loading

        do {
            let dash = try await api.getDashboard(userId: userId)
            var cravings: [VapeCravingLogDTO] = []
            if !dash.profile.id.isEmpty {
                cravings = (try? await api.getCravings(profileId: dash.profile.id, userId: userId)) ?? []
            }
            state = HomeQuitVapeState(
                dashboard: dash, recentCravings: cravings,
                isLoading: false, failed: false, hasProfile: true
            )
        } catch APIError.httpStatus(let code, _) where code == 404 {
            state = HomeQuitVapeState(
                dashboard: nil, recentCravings: [],
                isLoading: false, failed: false, hasProfile: false
            )
        } catch {
            state = HomeQuitVapeState(
                dashboard: nil, recentCravings: [],
                isLoading: false, failed: true, hasProfile: false
            )
        }
    }

    /// Soft refresh — update data silently without showing loading shimmer
    private func softRefresh(userId: String) async {
        do {
            let dash = try await api.getDashboard(userId: userId)
            var cravings: [VapeCravingLogDTO] = []
            if !dash.profile.id.isEmpty {
                cravings = (try? await api.getCravings(profileId: dash.profile.id, userId: userId)) ?? []
            }
            state = HomeQuitVapeState(
                dashboard: dash, recentCravings: cravings,
                isLoading: false, failed: false, hasProfile: true
            )
        } catch {
            // Silently fail — keep existing state
        }
    }

    func refresh(userId: String) async {
        loadedUserId = nil
        await load(userId: userId)
    }

    /// Quick-log puffs from the home tile
    func quickLogPuffs(count: Int, userId: String) async -> Bool {
        guard let profileId = state.dashboard?.profile.id else { return false }
        let req = LogCravingRequestDTO(
            intensity: 5, trigger: "habit", resisted: false,
            durationSeconds: nil, notes: nil, copingStrategy: nil,
            location: nil, puffCount: count, occurredAt: nil
        )
        do {
            _ = try await api.logCraving(profileId: profileId, userId: userId, request: req)
            await softRefresh(userId: userId)
            return true
        } catch {
            return false
        }
    }

    /// Quick-log a resisted craving from the home tile
    func quickLogResisted(userId: String) async -> Bool {
        guard let profileId = state.dashboard?.profile.id else { return false }
        let req = LogCravingRequestDTO(
            intensity: 5, trigger: "habit", resisted: true,
            durationSeconds: nil, notes: nil, copingStrategy: nil,
            location: nil, puffCount: 0, occurredAt: nil
        )
        do {
            _ = try await api.logCraving(profileId: profileId, userId: userId, request: req)
            await softRefresh(userId: userId)
            return true
        } catch {
            return false
        }
    }
}
