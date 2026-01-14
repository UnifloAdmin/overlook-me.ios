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
    
    func fetchCompletionLogs(
        habitId: String,
        userId: String,
        oauthId: String?,
        pageSize: Int?
    ) async throws -> [HabitCompletionLogDTO]
    
    func logHabitCompletion(
        habitId: String,
        userId: String,
        oauthId: String?,
        completion: LogHabitCompletionRequestDTO
    ) async throws -> DailyHabitDTO
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
    
    func fetchCompletionLogs(
        habitId: String,
        userId: String,
        oauthId: String?,
        pageSize: Int? = 50
    ) async throws -> [HabitCompletionLogDTO] {
        let entries = try await api.getCompletionLogs(
            habitId: habitId,
            userId: userId,
            oauthId: oauthId,
            startDate: nil,
            endDate: nil,
            page: nil,
            pageSize: pageSize
        )
        
        return entries.map {
            HabitCompletionLogDTO(
                date: $0.date,
                completed: $0.completed,
                value: nil,
                notes: $0.generalNotes,
                completedAt: $0.completedAt,
                wasSkipped: $0.wasSkipped
            )
        }
    }
    
    func logHabitCompletion(
        habitId: String,
        userId: String,
        oauthId: String?,
        completion: LogHabitCompletionRequestDTO
    ) async throws -> DailyHabitDTO {
        return try await api.logCompletion(
            habitId: habitId,
            userId: userId,
            completion: completion,
            oauthId: oauthId
        )
    }
    
    private static var defaultDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        // Use the user's local day when querying `GET /dailyhabits?date=...`.
        // Using UTC here can shift the day for positive offsets (e.g. IST) and cause
        // the UI to think "today" has no logs even when it does.
        formatter.calendar = .current
        formatter.timeZone = .current
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
    
    func fetchCompletionLogs(
        habitId: String,
        userId: String,
        oauthId: String?,
        pageSize: Int?
    ) async throws -> [HabitCompletionLogDTO] {
        return []
    }
    
    func logHabitCompletion(
        habitId: String,
        userId: String,
        oauthId: String?,
        completion: LogHabitCompletionRequestDTO
    ) async throws -> DailyHabitDTO {
        fatalError("Stub not implemented")
    }
}

