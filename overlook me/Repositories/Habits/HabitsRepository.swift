import Foundation

/// Contract for habit data operations.
protocol HabitsRepository {
    func fetchHabits(
        userId: String,
        oauthId: String?,
        queryDate: Date?,
        isActive: Bool,
        isArchived: Bool
    ) async throws -> [DailyHabitDTO]
}

// MARK: - Real Implementation

struct RealHabitsRepository: HabitsRepository {
    private let api: DailyHabitsAPI
    private let dateFormatter: DateFormatter
    
    init(api: DailyHabitsAPI, dateFormatter: DateFormatter = Self.defaultDateFormatter) {
        self.api = api
        self.dateFormatter = dateFormatter
    }
    
    func fetchHabits(
        userId: String,
        oauthId: String?,
        queryDate: Date?,
        isActive: Bool,
        isArchived: Bool
    ) async throws -> [DailyHabitDTO] {
        let dateString = queryDate.map { dateFormatter.string(from: $0) }
        return try await api.getHabits(
            userId: userId,
            oauthId: oauthId,
            habitId: nil,
            category: nil,
            priority: nil,
            isPinned: nil,
            isActive: isActive,
            isArchived: isArchived,
            date: dateString
        )
    }
    
    private static var defaultDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}

// MARK: - Stub Implementation

struct StubHabitsRepository: HabitsRepository {
    func fetchHabits(
        userId: String,
        oauthId: String?,
        queryDate: Date?,
        isActive: Bool,
        isArchived: Bool
    ) async throws -> [DailyHabitDTO] {
        return []
    }
}

