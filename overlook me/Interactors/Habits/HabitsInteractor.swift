import Foundation

protocol HabitsInteractor {
    func loadHabits(for date: Date?) async
    func loadCompletionLogs(for date: Date) async
    func performHabitAction(_ action: HabitAction, for date: Date) async
    func clearLocalCompletions()
    func clearActionError()
}

enum HabitsError: LocalizedError {
    case missingUser
    
    var errorDescription: String? {
        "Unable to load habits without an authenticated user."
    }
}

@MainActor
struct RealHabitsInteractor: HabitsInteractor {
    let appState: Store<AppState>
    let repository: HabitsRepository
    
    private let isoDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = .current
        formatter.timeZone = .current
        return formatter
    }()
    
    private static let utcDayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    func loadHabits(for date: Date? = nil) async {
        appState.state.habits.isLoading = true
        appState.state.habits.error = nil
        
        guard let authUser = appState.state.auth.user else {
            appState.state.habits.habits = []
            appState.state.habits.error = HabitsError.missingUser
            appState.state.habits.isLoading = false
            return
        }
        let userId = authUser.id
        let oauthId = authUser.oauthId.isEmpty ? nil : authUser.oauthId
        
        do {
            let habits = try await repository.fetchHabits(
                userId: userId,
                oauthId: oauthId,
                queryDate: date,
                isActive: true,
                isArchived: false
            )
            appState.state.habits.habits = habits
            appState.state.habits.isLoading = false
        } catch is CancellationError {
            appState.state.habits.isLoading = false
        } catch let urlError as URLError where urlError.code == .cancelled {
            appState.state.habits.isLoading = false
        } catch {
            appState.state.habits.error = error
            appState.state.habits.isLoading = false
        }
    }
    
    func loadCompletionLogs(for date: Date) async {
        guard let authUser = appState.state.auth.user else { return }
        let userId = authUser.id
        let oauthId = authUser.oauthId.isEmpty ? nil : authUser.oauthId
        let dateString = Self.dayFormatter.string(from: date)
        
        var habitsWithLogs = appState.state.habits.habits
        
        #if DEBUG
        print("🔄 Fetching completion logs for \(habitsWithLogs.count) habits (date: \(dateString))...")
        #endif
        
        // Fetch logs in parallel using TaskGroup
        await withTaskGroup(of: (String, [HabitCompletionLogDTO]).self) { group in
            for habit in habitsWithLogs {
                group.addTask {
                    do {
                        let logs = try await self.repository.fetchCompletionLogs(
                            habitId: habit.id,
                            userId: userId,
                            oauthId: oauthId,
                            pageSize: 50
                        )
                        #if DEBUG
                        print("   ✅ \(habit.name): \(logs.count) logs")
                        #endif
                        return (habit.id, logs)
                    } catch {
                        #if DEBUG
                        print("   ❌ \(habit.name): \(error)")
                        #endif
                        return (habit.id, [])
                    }
                }
            }
            
            // Collect results as they come in (parallel execution)
            for await (habitId, logs) in group {
                if let index = habitsWithLogs.firstIndex(where: { $0.id == habitId }) {
                    habitsWithLogs[index] = DailyHabitDTO(
                        id: habitsWithLogs[index].id,
                        userId: habitsWithLogs[index].userId,
                        oauthId: habitsWithLogs[index].oauthId,
                        name: habitsWithLogs[index].name,
                        description: habitsWithLogs[index].description,
                        category: habitsWithLogs[index].category,
                        color: habitsWithLogs[index].color,
                        icon: habitsWithLogs[index].icon,
                        frequency: habitsWithLogs[index].frequency,
                        targetDays: habitsWithLogs[index].targetDays,
                        isIndefinite: habitsWithLogs[index].isIndefinite,
                        remindersEnabled: habitsWithLogs[index].remindersEnabled,
                        priority: habitsWithLogs[index].priority,
                        isPinned: habitsWithLogs[index].isPinned,
                        isPositive: habitsWithLogs[index].isPositive,
                        sortOrder: habitsWithLogs[index].sortOrder,
                        tags: habitsWithLogs[index].tags,
                        isActive: habitsWithLogs[index].isActive,
                        isArchived: habitsWithLogs[index].isArchived,
                        currentStreak: habitsWithLogs[index].currentStreak,
                        longestStreak: habitsWithLogs[index].longestStreak,
                        totalCompletions: habitsWithLogs[index].totalCompletions,
                        completionRate: habitsWithLogs[index].completionRate,
                        completionLogs: logs,
                        createdAt: habitsWithLogs[index].createdAt,
                        updatedAt: habitsWithLogs[index].updatedAt
                    )
                }
            }
        }
        
        appState.state.habits.habits = habitsWithLogs
        reconcileLocalCompletions(with: habitsWithLogs, date: date)
        
        #if DEBUG
        print("📦 Final state: \(habitsWithLogs.count) habits with completion logs")
        for habit in habitsWithLogs {
            let logsCount = habit.completionLogs?.count ?? 0
            let todayLog = habit.completionLogs?.first(where: { log in
                guard let logDate = Self.parseDate(log.date) else { return false }
                let logKey = Self.utcDayKeyFormatter.string(from: logDate)
                return logKey == dateString
            })
            if let todayLog = todayLog {
                print("   📋 \(habit.name): \(logsCount) logs | Today: completed=\(todayLog.completed), skipped=\(todayLog.wasSkipped ?? false)")
            } else {
                print("   📋 \(habit.name): \(logsCount) logs | Today: NO LOG")
            }
        }
        #endif
    }
    
    func performHabitAction(_ action: HabitAction, for date: Date) async {
        guard appState.state.habits.pendingActionHabitId == nil else { return }
        
        // Check if already logged
        let dayKey = Self.dayFormatter.string(from: date)
        if hasLoggedAction(for: action.habit, dayKey: dayKey) {
            let dateLabel = Self.displayDateFormatter.string(from: date)
            appState.state.habits.actionError = "You've already logged this habit for \(dateLabel)."
            return
        }
        
        guard let authUser = appState.state.auth.user else {
            appState.state.habits.actionError = "Please sign in again to update this habit."
            return
        }
        
        let userId = authUser.id
        let oauthId = authUser.oauthId.isEmpty ? nil : authUser.oauthId
        
        appState.state.habits.pendingActionHabitId = action.habit.id
        
        do {
            let request = action.makeRequest(selectedDate: date, isoFormatter: isoDateFormatter)
            let updatedHabit = try await repository.logHabitCompletion(
                habitId: action.habit.id,
                userId: userId,
                oauthId: oauthId,
                completion: request
            )
            
            // Update habits in state
            appState.state.habits.habits = appState.state.habits.habits.map { current in
                current.id == updatedHabit.id ? updatedHabit : current
            }
            
            // Store local completion
            appState.state.habits.localCompletions[updatedHabit.id] = HabitCompletionLogDTO(
                date: request.date,
                completed: request.completed,
                value: request.value,
                notes: request.notes,
                completedAt: isoDateFormatter.string(from: Date()),
                wasSkipped: request.wasSkipped ?? false
            )
            
            #if DEBUG
            print("✅ Created local completion for \(updatedHabit.name):")
            print("   Date: \(request.date)")
            print("   Completed: \(request.completed)")
            print("   WasSkipped: \(request.wasSkipped ?? false)")
            #endif
        } catch {
            appState.state.habits.actionError = "We couldn't update \"\(action.habit.name)\". Please try again."
        }
        
        appState.state.habits.pendingActionHabitId = nil
    }
    
    func clearLocalCompletions() {
        appState.state.habits.localCompletions = [:]
    }
    
    func clearActionError() {
        appState.state.habits.actionError = nil
    }
    
    // MARK: - Private Helpers
    
    private func reconcileLocalCompletions(with habits: [DailyHabitDTO], date: Date) {
        guard !appState.state.habits.localCompletions.isEmpty else { return }
        let dayKey = Self.dayFormatter.string(from: date)
        
        appState.state.habits.localCompletions = appState.state.habits.localCompletions.filter { habitId, override in
            guard matchesLocalDay(override.date, dayKey: dayKey) else { return false }
            guard let logs = habits.first(where: { $0.id == habitId })?.completionLogs else {
                return true
            }
            return !logs.contains(where: { log in
                guard let logDate = Self.parseDate(log.date) else { return false }
                let logKey = Self.utcDayKeyFormatter.string(from: logDate)
                return logKey == dayKey
            })
        }
    }
    
    private func matchesLocalDay(_ dateString: String, dayKey: String) -> Bool {
        guard let logDate = Self.parseDate(dateString) else {
            return dateString.hasPrefix(dayKey)
        }
        let logKey = Self.utcDayKeyFormatter.string(from: logDate)
        return logKey == dayKey
    }
    
    private func hasLoggedAction(for habit: DailyHabitDTO, dayKey: String) -> Bool {
        // Check local completions first
        if let override = appState.state.habits.localCompletions[habit.id],
           matchesLocalDay(override.date, dayKey: dayKey) {
            return true
        }
        
        // Check habit logs
        guard let logs = habit.completionLogs else { return false }
        return logs.contains(where: { log in
            guard let logDate = Self.parseDate(log.date) else { return false }
            let logKey = Self.utcDayKeyFormatter.string(from: logDate)
            return logKey == dayKey
        })
    }
    
    private static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    // MARK: - Date Parsing
    
    private static func parseDate(_ string: String) -> Date? {
        if let date = isoFormatterWithFractional.date(from: string) {
            return date
        }
        if let date = isoFormatter.date(from: string) {
            return date
        }
        if let date = isoNoTimezoneDateTimeFormatter.date(from: string) {
            return date
        }
        return isoDateOnlyFormatter.date(from: string)
    }
    
    private static let isoFormatterWithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private static let isoNoTimezoneDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()

    private static let isoDateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

struct StubHabitsInteractor: HabitsInteractor {
    func loadHabits(for date: Date?) async {}
    func loadCompletionLogs(for date: Date) async {}
    func performHabitAction(_ action: HabitAction, for date: Date) async {}
    func clearLocalCompletions() {}
    func clearActionError() {}
}

