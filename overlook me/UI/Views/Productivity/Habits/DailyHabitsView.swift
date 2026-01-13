import SwiftUI
#if canImport(QuartzCore)
import QuartzCore
#endif
#if canImport(UIKit)
import UIKit
#endif

struct DailyHabitsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.injected) private var container: DIContainer
    @EnvironmentObject private var tabBar: TabBarStyleStore
    @State private var isPresentingAddHabit = false
    @State private var selectedDate = Date()
    @State private var lastLoadedSignature: String?
    @State private var lastLogsFetchDate: String? // Track when we last fetched logs (YYYY-MM-DD)
    @State private var displayedHabits: [DailyHabitDTO] = []
    @State private var selectedHabitForDetail: DailyHabitDTO?
    @State private var selectedHabitForNotification: DailyHabitDTO?
    @State private var selectedHabitForPomodoro: DailyHabitDTO?
    @State private var selectedHabitForCompletion: (habit: DailyHabitDTO, actionType: HabitCompletionSheet.HabitActionType)?
    @State private var notificationUpdateTrigger = UUID()
    @State private var localCompletions: [String: HabitCompletionLogDTO] = [:]
    @State private var actionErrorMessage: String?
    @State private var pendingHabitId: String?
    @State private var showFullInsight = false
    @State private var isBootstrappingHabits = true
    
    private var habitsState: AppState.HabitsState { container.appState.state.habits }
    private var habitsInteractor: HabitsInteractor { container.interactors.habitsInteractor }
    private var backendUserId: String? {
        container.appState.state.auth.user?.id
    }
    
    private let habitAPI = DailyHabitsAPI(client: LoggingAPIClient(base: AppAPIClient.live()))
    private let isoDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            gradientLayer
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    headerPlaceholder
                    habitsSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 130)  // Increased padding to push header content down
                .padding(.bottom, 48)
                .safeAreaPadding(.top, 0)
            }
            // Ensure bounce is only enabled when there's actual scrollable content.
            .scrollBounceBehavior(.basedOnSize, axes: [.vertical, .horizontal])
            .refreshable { await loadHabitsIfNeeded(force: true) }
        }
        .ignoresSafeArea(edges: .top)
        .navigationTitle("Daily Habits")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: handleBackAction) {
                    Label("Back", systemImage: "chevron.left")
                        .labelStyle(.titleAndIcon)
                        .font(.body.weight(.semibold))
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { isPresentingAddHabit = true }) {
                    Image(systemName: "plus")
                        .font(.title3.weight(.semibold))
                }
                .accessibilityLabel("Add Habit")
            }
        }
        .sheet(isPresented: $isPresentingAddHabit) {
            AddNewHabitView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedHabitForDetail) { habit in
            HabitViewSheet(
                habit: habit,
                completion: completionLog(for: habit),
                isPerformingAction: pendingHabitId == habit.id,
                onAction: handleHabitAction
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedHabitForNotification, onDismiss: {
            notificationUpdateTrigger = UUID()
        }) { habit in
            HabitNotification(habit: habit)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedHabitForPomodoro) { habit in
            PomodoroSheet(habit: habit)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: Binding(
            get: { selectedHabitForCompletion.map { $0.habit } },
            set: { _ in selectedHabitForCompletion = nil }
        )) { habit in
            if let context = selectedHabitForCompletion {
                HabitCompletionSheet(
                    habit: context.habit,
                    actionType: context.actionType,
                    onComplete: { data in
                        handleCompletionSubmit(habit: context.habit, data: data)
                        selectedHabitForCompletion = nil
                    },
                    onCancel: {
                        selectedHabitForCompletion = nil
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
        .task { await loadHabitsIfNeeded(force: true) }
        .onChange(of: backendUserId) { _ in
            localCompletions = [:]
            Task { await loadHabitsIfNeeded(force: true) }
        }
        .onChange(of: selectedDate) { _ in
            localCompletions = [:]
            Task { await loadHabitsIfNeeded(force: true) }
        }
        .alert("Unable to update habit", isPresented: Binding(
            get: { actionErrorMessage != nil },
            set: { newValue in if !newValue { actionErrorMessage = nil } })
        ) {
            Button("OK", role: .cancel) { actionErrorMessage = nil }
        } message: {
            Text(actionErrorMessage ?? "")
        }
    }
    
    
    private var headerPlaceholder: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(insightParagraph)
                .font(.footnote)
                .foregroundStyle(headerTextColor)
                .lineSpacing(4)
                .lineLimit(showFullInsight ? nil : 4)
            Button(showFullInsight ? "read less" : "read more") {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showFullInsight.toggle()
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundColor(headerTextColor)
        }
        .padding(.horizontal, 4)
    }
    
    private var headerTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.9) : Color(.label)
    }
    private let insightParagraph = """
lorem ipsum dolor sit amet, habitasse platea dictumst viverra tempor, natoque penatibus et magnis dis parturient montes. nullam habitant morbi tristique senectus et netus ac turpis egestas euismod. integer cursus justo luctus mi malesuada, sed rutrum sapien pretium. maecenas mattis ligula pulvinar lacus sodales bibendum, finibus ligula semper mauris ullamcorper. quisque congue risus lectus, consequat tortor dapibus fringilla odio. proin posuere ante vel elit posuere luctus, quis faucibus lorem rhoncus. vestibulum enim tellus, molestie facilisis pharetra id, pulvinar id nisl. vivamus ultricies arcu nibh, iaculis lacinia neque porta ut. suspendisse fermentum metus augue, fermentum gravida quam dictum et. curabitur magna quam, congue at nisl vel, fermentum viverra erat. quisque commodo feugiat erat non varius. in vehicula mauris nunc, interdum aliquam libero tristique non. sed vulputate eros vitae nisl gravida euismod ornare tellus. pellentesque quis magna dictum, mattis diam eu, convallis ligula. morbi fringilla sapien in erat auctor dapibus. nam eget felis convallis, vehicula arcu eget, gravida orci. fusce malesuada molestie magna, eget imperdiet felis pretium ac. duis massa elit, efficitur eget interdum sit amet, suscipit at lacus. sed sed vehicula lorem, quis feugiat nisi. curabitur volutpat nisl vitae arcu tincidunt bibendum suscipit augue. integer dignissim ligula in odio sagittis pharetra.
"""
    
    @ViewBuilder
    private var habitsSection: some View {
        if shouldShowInitialLoader || habitsState.isLoading {
            habitsLoadingView
        } else if let error = habitsState.error {
            habitsErrorView(error)
        } else if displayedHabits.isEmpty {
            habitsEmptyView
        } else {
            VStack(spacing: 16) {
                ForEach(displayedHabits) { habit in
                    HabitCardView(
                        habit: habit,
                        completion: completionLog(for: habit),
                        isPerformingAction: pendingHabitId == habit.id,
                        onAction: handleHabitAction,
                        onNotification: { selectedHabitForNotification = $0 },
                        onPomodoro: { selectedHabitForPomodoro = $0 },
                        onSelect: { selectedHabitForDetail = $0 },
                        notificationUpdateTrigger: notificationUpdateTrigger
                    )
                }
            }
        }
    }
    
    private var shouldShowInitialLoader: Bool {
        isBootstrappingHabits && displayedHabits.isEmpty
    }
    
    private var habitsLoadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading your habits…")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
    
    private func habitsErrorView(_ error: Error) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundColor(.orange)
            Text("We couldn't load your habits.")
                .font(.headline)
            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await loadHabitsIfNeeded(force: true) }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(cardBackground)
    }
    
    private var habitsEmptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No habits yet")
                .font(.headline)
            Text("Build your first habit to see it here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                isPresentingAddHabit = true
            } label: {
                Label("Create Habit", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(cardBackground)
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(DailyHabitsPalette.cardBackground(for: colorScheme))
            .shadow(color: DailyHabitsPalette.cardShadow(for: colorScheme), radius: 8, y: 6)
    }
    
    private func loadHabitsIfNeeded(force: Bool = false) async {
        guard let userId = backendUserId else {
            await MainActor.run {
                isBootstrappingHabits = false
            }
            return
        }
        let dateString = Self.dayFormatter.string(from: selectedDate)
        let signature = "\(userId)|\(dateString)"
        
        // Check if we need to fetch logs (different day or forced)
        let needsLogsFetch = force || lastLogsFetchDate != dateString
        
        guard force || lastLoadedSignature != signature || habitsState.habits.isEmpty else {
            await MainActor.run {
                displayedHabits = container.appState.state.habits.habits
                isBootstrappingHabits = false
            }
            return
        }
        lastLoadedSignature = signature
        await habitsInteractor.loadHabits(for: selectedDate)
        
        var habitsWithLogs = container.appState.state.habits.habits
        
        // Only fetch logs if it's a new day or forced refresh
        if needsLogsFetch {
            #if DEBUG
            print("🔄 Fetching completion logs for \(habitsWithLogs.count) habits (date: \(dateString))...")
            #endif
            
            let oauthId = container.appState.state.auth.user?.oauthId
            
            // Fetch logs in parallel using TaskGroup
            await withTaskGroup(of: (String, [HabitCompletionLogDTO]).self) { group in
                for habit in habitsWithLogs {
                    group.addTask {
                        do {
                            let entries = try await self.habitAPI.getCompletionLogs(
                                habitId: habit.id,
                                userId: userId,
                                oauthId: oauthId,
                                startDate: nil,
                                endDate: nil,
                                page: nil,
                                pageSize: 50
                            )
                            let logs = entries.map {
                                HabitCompletionLogDTO(
                                    date: $0.date,
                                    completed: $0.completed,
                                    value: nil,
                                    notes: $0.generalNotes,
                                    completedAt: $0.completedAt,
                                    wasSkipped: $0.wasSkipped
                                )
                            }
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
                        
                        // Update displayed habits immediately as each habit loads (progressive rendering)
                        await MainActor.run {
                            if let displayIndex = displayedHabits.firstIndex(where: { $0.id == habitId }) {
                                displayedHabits[displayIndex] = habitsWithLogs[index]
                            }
                        }
                    }
                }
            }
            
            await MainActor.run {
                lastLogsFetchDate = dateString // Cache for this day
            }
        }
        
        await MainActor.run {
            displayedHabits = habitsWithLogs
            container.appState.state.habits.habits = habitsWithLogs
            
            #if DEBUG
            print("📦 Final state: \(displayedHabits.count) habits with completion logs")
            for habit in displayedHabits {
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
            
            reconcileLocalCompletions(with: displayedHabits)
            if let detailHabit = selectedHabitForDetail,
               let refreshed = displayedHabits.first(where: { $0.id == detailHabit.id }) {
                selectedHabitForDetail = refreshed
            }
            isBootstrappingHabits = false
        }
    }

    private func reconcileLocalCompletions(with habits: [DailyHabitDTO]) {
        guard !localCompletions.isEmpty else { return }
        let dayKey = Self.dayFormatter.string(from: selectedDate)
        localCompletions = localCompletions.filter { habitId, override in
            guard override.matchesLocalDay(dayKey: dayKey) else { return false }
            guard let logs = habits.first(where: { $0.id == habitId })?.completionLogs else {
                return true
            }
            // Check if any log matches this day using UTC parsing
            return !logs.contains(where: { log in
                guard let logDate = Self.parseDate(log.date) else { return false }
                let logKey = Self.utcDayKeyFormatter.string(from: logDate)
                return logKey == dayKey
            })
        }
    }

    private func handleHabitAction(_ action: HabitAction) {
        guard pendingHabitId == nil else { return }
        guard !hasLoggedAction(for: action.habit) else {
            let dateLabel = Self.displayDateFormatter.string(from: selectedDate)
            actionErrorMessage = "You've already logged this habit for \(dateLabel)."
            return
        }
        
        // For SKIP and FAILED actions, show the completion sheet
        switch action {
        case .skipDay(let habit):
            selectedHabitForCompletion = (habit, .skip)
            return
        case .failedToResist(let habit):
            selectedHabitForCompletion = (habit, .failedToResist)
            return
        case .checkIn, .resisted:
            // For SUCCESS actions, complete immediately
            break
        }
        
        guard let userId = backendUserId else {
            actionErrorMessage = "Please sign in again to update this habit."
            return
        }
        
        let oauthId = container.appState.state.auth.user?.oauthId
        let targetDate = selectedDate
        let dayKey = Self.dayFormatter.string(from: targetDate)
        pendingHabitId = action.habit.id
        
        Task {
            do {
                let request = action.makeRequest(selectedDate: targetDate, isoFormatter: isoDateFormatter)
                let updatedHabit = try await habitAPI.logCompletion(
                    habitId: action.habit.id,
                    userId: userId,
                    completion: request,
                    oauthId: oauthId
                )
                
                await MainActor.run {
                    container.appState.state.habits.habits = container.appState.state.habits.habits.map { current in
                        current.id == updatedHabit.id ? updatedHabit : current
                    }
                    displayedHabits = displayedHabits.map { current in
                        current.id == updatedHabit.id ? updatedHabit : current
                    }
                    if let detailHabit = selectedHabitForDetail, detailHabit.id == updatedHabit.id {
                        selectedHabitForDetail = updatedHabit
                    }
                    // Use the same date format as backend (ISO with time) for consistency
                    localCompletions[updatedHabit.id] = HabitCompletionLogDTO(
                        date: request.date,  // Use the date from the request (ISO format)
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
                }
            } catch {
                await MainActor.run {
                    actionErrorMessage = "We couldn't update “\(action.habit.name)”. Please try again."
                }
            }
            
            await MainActor.run {
                pendingHabitId = nil
            }
        }
    }
    
    private func handleCompletionSubmit(habit: DailyHabitDTO, data: HabitCompletionData) {
        guard let userId = backendUserId else {
            actionErrorMessage = "Please sign in again to update this habit."
            return
        }
        
        let oauthId = container.appState.state.auth.user?.oauthId
        let targetDate = selectedDate
        pendingHabitId = habit.id
        
        Task {
            do {
                let localCalendar = Calendar.current
                let dayStartLocal = localCalendar.startOfDay(for: targetDate)
                
                let localDateFormatter = DateFormatter()
                localDateFormatter.dateFormat = "yyyy-MM-dd"
                localDateFormatter.timeZone = localCalendar.timeZone
                let dateString = localDateFormatter.string(from: dayStartLocal) + "T00:00:00.000Z"
                
                let completedAt = isoDateFormatter.string(from: Date())
                
                let request = LogHabitCompletionRequestDTO(
                    habitId: habit.id,
                    date: dateString,
                    completed: data.completed,
                    value: nil,
                    notes: data.notes,
                    wasSkipped: data.wasSkipped,
                    completedAt: completedAt,
                    metrics: [],
                    reason: data.reason,
                    generalNotes: data.notes
                )
                
                let updatedHabit = try await habitAPI.logCompletion(
                    habitId: habit.id,
                    userId: userId,
                    completion: request,
                    oauthId: oauthId
                )
                
                await MainActor.run {
                    container.appState.state.habits.habits = container.appState.state.habits.habits.map { current in
                        current.id == updatedHabit.id ? updatedHabit : current
                    }
                    displayedHabits = displayedHabits.map { current in
                        current.id == updatedHabit.id ? updatedHabit : current
                    }
                    if let detailHabit = selectedHabitForDetail, detailHabit.id == updatedHabit.id {
                        selectedHabitForDetail = updatedHabit
                    }
                    localCompletions[updatedHabit.id] = HabitCompletionLogDTO(
                        date: request.date,
                        completed: request.completed,
                        value: request.value,
                        notes: request.notes,
                        completedAt: completedAt,
                        wasSkipped: request.wasSkipped ?? false
                    )
                }
            } catch {
                await MainActor.run {
                    actionErrorMessage = "We couldn't update \"\(habit.name)\". Please try again."
                }
            }
            
            await MainActor.run {
                pendingHabitId = nil
            }
        }
    }

    private func completionLog(for habit: DailyHabitDTO) -> HabitCompletionLogDTO? {
        // Use local timezone for the selected date (UI date)
        let dayKey = Self.dayFormatter.string(from: selectedDate)
        
        #if DEBUG
        print("🔍 completionLog for habit: \(habit.name)")
        print("   📅 Selected date (local): \(selectedDate)")
        print("   🔑 Day key (local): \(dayKey)")
        print("   💾 Local completions count: \(localCompletions.count)")
        if let localComp = localCompletions[habit.id] {
            print("   ✅ Found local completion: \(localComp.date)")
        }
        #endif
        
        // Check local completions first
        if let override = localCompletions[habit.id], override.matchesLocalDay(dayKey: dayKey) {
            #if DEBUG
            print("   ✓ Returning local completion")
            #endif
            return override
        }
        
        // Check habit logs - need to parse UTC dates and match against local day
        guard let logs = habit.completionLogs else { 
            #if DEBUG
            print("   ❌ No completion logs found")
            #endif
            return nil 
        }
        
        #if DEBUG
        print("   📋 Checking \(logs.count) logs:")
        for (index, log) in logs.enumerated() {
            print("      Log \(index): \(log.date)")
            if let logDate = Self.parseDate(log.date) {
                let logKey = Self.utcDayKeyFormatter.string(from: logDate)
                print("         Parsed date: \(logDate)")
                print("         UTC key: \(logKey)")
                print("         Match? \(logKey == dayKey)")
            } else {
                print("         ⚠️ Failed to parse")
            }
        }
        #endif
        
        return logs.first(where: { log in
            guard let logDate = Self.parseDate(log.date) else { return false }
            // Log dates are stored as UTC midnight, extract the date part using UTC formatter
            let logKey = Self.utcDayKeyFormatter.string(from: logDate)
            return logKey == dayKey
        })
    }
    
    private func hasLoggedAction(for habit: DailyHabitDTO) -> Bool {
        completionLog(for: habit) != nil
    }

    private func handleBackAction() {
        if tabBar.config == .dailyHabits {
            tabBar.config = .default
        } else {
            dismiss()
        }
    }
}

private extension Color {
    func darker(for scheme: ColorScheme) -> Color {
        if scheme == .dark {
            return self.opacity(0.9)
        }
        return self.opacity(0.8)
    }
}

private extension DailyHabitsView {
    // Formatter for UI dates (Local Timezone) - matches HabitCycleTracker
    // Used to generate keys for the selected date
    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = .current
        formatter.timeZone = .current
        return formatter
    }()
    
    // Formatter for Log dates (UTC) - matches HabitCycleTracker
    // Used to parse/match the YYYY-MM-DD part from the stored UTC logs
    static let utcDayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    // MARK: - Date Parsing (matches HabitCycleTracker)
    
    static func parseDate(_ string: String) -> Date? {
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

    // Backend may send `"2026-01-12T00:00:00"` (no timezone). Assume UTC.
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

// MARK: - Background Layers

private extension DailyHabitsView {
    @ViewBuilder
    private var gradientLayer: some View {
        VStack(spacing: 0) {
            DailyHabitsPalette.headerGradient(for: colorScheme)
                .frame(height: 280)
                .overlay(DailyHabitsPalette.highlightGradient(for: colorScheme))
                .overlay(DailyHabitsPalette.glossOverlay(for: colorScheme))
                .overlay(alignment: .bottom) {
                    DailyHabitsPalette.fadeOverlay(for: colorScheme)
                        .frame(height: 98)
                }
                .frame(maxWidth: .infinity)
            Spacer()
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
    
    // MARK: - Removed unused functions
    // Removed: content(topInset:size:), headerHeight(for:), contentTopPadding(topInset:headerHeight:)
    // These were causing GeometryReader-based layout recalculations
}

// MARK: - Supporting Views

private struct HabitCardView: View {
    @Environment(\.colorScheme) private var colorScheme
    let habit: DailyHabitDTO
    let completion: HabitCompletionLogDTO?
    let isPerformingAction: Bool
    let onAction: (HabitAction) -> Void
    let onNotification: (DailyHabitDTO) -> Void
    let onPomodoro: (DailyHabitDTO) -> Void
    let onSelect: (DailyHabitDTO) -> Void
    let notificationUpdateTrigger: UUID
    let extraContent: AnyView?
    @State private var celebrationTrigger = 0
    @State private var notificationCount: Int = 0
    
    init(
        habit: DailyHabitDTO,
        completion: HabitCompletionLogDTO?,
        isPerformingAction: Bool,
        onAction: @escaping (HabitAction) -> Void,
        onNotification: @escaping (DailyHabitDTO) -> Void,
        onPomodoro: @escaping (DailyHabitDTO) -> Void,
        onSelect: @escaping (DailyHabitDTO) -> Void,
        notificationUpdateTrigger: UUID = UUID(),
        extraContent: AnyView? = nil
    ) {
        self.habit = habit
        self.completion = completion
        self.isPerformingAction = isPerformingAction
        self.onAction = onAction
        self.onNotification = onNotification
        self.onPomodoro = onPomodoro
        self.onSelect = onSelect
        self.notificationUpdateTrigger = notificationUpdateTrigger
        self.extraContent = extraContent
    }
    
    private var priorityLabel: String? { habit.priority?.capitalized }
    private var frequencyLabel: String {
        (habit.frequency ?? "daily").replacingOccurrences(of: "_", with: " ").capitalized
    }
    private var isPositiveHabit: Bool { habit.isPositive ?? true }
    private var isActionDisabled: Bool { isPerformingAction || completion != nil }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerRow
            
            Divider()
                .frame(height: 0.5)
                .opacity(0.5)
            
            metaRow
            
            Divider()
                .frame(height: 0.5)
                .opacity(0.5)
            
            actionRow
            
            if let extraContent {
                Divider()
                    .frame(height: 0.5)
                    .opacity(0.5)
                extraContent
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DailyHabitsPalette.cardBackground(for: colorScheme))
        .cornerRadius(16)
        .shadow(color: DailyHabitsPalette.cardShadow(for: colorScheme), radius: 8, y: 4)
        .onTapGesture { onSelect(habit) }
    }
    
    private var headerRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(habit.name)
                .font(.title2.weight(.bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)
                .truncationMode(.tail)
            if let description = habit.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
    }
    
    private var metaRow: some View {
        HStack(spacing: 8) {
            Image(systemName: isPositiveHabit ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .font(.caption)
                .foregroundStyle(isPositiveHabit ? .green : .red)
            
            Text(isPositiveHabit ? "Build" : "Break")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            
            if let priority = priorityLabel {
                Text("•")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                
                priorityIcon(for: priority)
                
                Text(priority)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            
            Text("•")
                .font(.caption)
                .foregroundStyle(.tertiary)
            
            Text(frequencyLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            
            Spacer(minLength: 0)
            
            // Pomodoro timer button
            Button {
                onPomodoro(habit)
            } label: {
                Image(systemName: "timer")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .padding(8)
                    .background(Color(uiColor: .secondarySystemFill))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Start Pomodoro timer")
            
            // Notification button
            Button {
                onNotification(habit)
            } label: {
                ZStack {
                    Image(systemName: "bell")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .background(Color(uiColor: .secondarySystemFill))
                        .clipShape(Circle())
                    
                    if notificationCount > 0 {
                        Text("\(notificationCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 16, height: 16)
                            .background(Color.red)
                            .clipShape(Circle())
                            .offset(x: 10, y: -10)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Habit notifications")
            .onAppear { updateNotificationCount() }
            .onChange(of: notificationUpdateTrigger) { _ in updateNotificationCount() }
        }
    }
    
    private func updateNotificationCount() {
        if let saved = UserDefaults.standard.array(forKey: "notifications_\(habit.id)") as? [Date] {
            notificationCount = saved.count
        } else {
            notificationCount = 0
        }
    }
    
    @ViewBuilder
    private func priorityIcon(for priority: String) -> some View {
        switch priority.lowercased() {
        case "high":
            Image(systemName: "exclamationmark")
                .font(.caption.weight(.bold))
                .foregroundStyle(.red)
        case "medium":
            Image(systemName: "chevron.up.2")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
        case "low":
            Image(systemName: "chevron.up")
                .font(.caption)
                .foregroundStyle(.blue)
        default:
            EmptyView()
        }
    }
    
    @ViewBuilder
    private var actionRow: some View {
        if let completion {
            completionStatusButton(for: completion)
        } else if isPositiveHabit {
            HStack(spacing: 12) {
                primaryActionButton(
                    title: "Check In",
                    systemIcon: "checkmark.circle.fill",
                    style: .checkIn,
                    action: .checkIn(habit)
                )
                secondaryActionButton(
                    title: "Skip This Day",
                    systemIcon: "minus.circle.fill",
                    tint: Color(.systemGray4),
                    action: .skipDay(habit)
                )
            }
        } else {
            HStack(spacing: 12) {
                primaryActionButton(
                    title: "Resisted",
                    systemIcon: "shield.checkered",
                    style: .resisted,
                    action: .resisted(habit)
                )
                secondaryActionButton(
                    title: "Failed to resist",
                    systemIcon: "exclamationmark.circle.fill",
                    tint: .red,
                    action: .failedToResist(habit)
                )
            }
        }
    }
    
    private func primaryActionButton(
        title: String,
        systemIcon: String,
        style: PrimaryActionStyle,
        action: HabitAction
    ) -> some View {
        let palette = style.palette(for: colorScheme)
        return Button {
            if !isActionDisabled {
                celebrationTrigger &+= 1
            }
            onAction(action)
        } label: {
            Label(title, systemImage: systemIcon)
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .foregroundStyle(Color.white)
                .background(
                    ZStack {
                        Capsule()
                            .fill(palette.fillColor)
                        
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .opacity(0.3)
                    }
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            .linearGradient(
                                colors: [
                                    Color.white.opacity(0.4),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .disabled(isActionDisabled)
        .opacity(isActionDisabled ? 0.6 : 1)
        .overlay(alignment: .top) {
            ConfettiEmitterView(trigger: celebrationTrigger)
                .frame(height: 140)
                .offset(y: -16)
                .allowsHitTesting(false)
        }
    }
    
    private func secondaryActionButton(
        title: String,
        systemIcon: String,
        tint: Color,
        action: HabitAction
    ) -> some View {
        return Button {
            onAction(action)
        } label: {
            Label(title, systemImage: systemIcon)
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .foregroundStyle(.secondary)
                .background(
                    ZStack {
                        Capsule()
                            .fill(.ultraThinMaterial)
                        
                        Capsule()
                            .fill(Color(uiColor: .secondarySystemFill))
                            .opacity(0.5)
                    }
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            Color.white.opacity(colorScheme == .dark ? 0.15 : 0.3),
                            lineWidth: 0.5
                        )
                )
        }
        .buttonStyle(.plain)
        .disabled(isActionDisabled)
        .opacity(isActionDisabled ? 0.6 : 1)
    }
    
    private func completionStatusButton(for completion: HabitCompletionLogDTO) -> some View {
        let status = statusAppearance(for: completion)
        return HStack(spacing: 8) {
            Image(systemName: status.icon)
                .font(.subheadline.weight(.semibold))
            Text(status.text)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.9)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(status.background)
        )
        .foregroundStyle(status.foreground)
    }
    
    private func statusAppearance(for completion: HabitCompletionLogDTO) -> (text: String, icon: String, background: Color, foreground: Color) {
        let backgroundOpacity = colorScheme == .dark ? 0.35 : 0.15
        let wasSkipped = completion.wasSkipped ?? false
        
        if wasSkipped {
            return (
                text: "Skipped today",
                icon: "minus.circle.fill",
                background: Color.orange.opacity(backgroundOpacity),
                foreground: .orange
            )
        }
        
        if completion.completed {
            return (
                text: isPositiveHabit ? "Checked in today" : "Resisted today",
                icon: isPositiveHabit ? "checkmark.circle.fill" : "shield.checkered",
                background: Color.green.opacity(backgroundOpacity),
                foreground: .green
            )
        }
        
        return (
            text: isPositiveHabit ? "Missed today" : "Failed to resist",
            icon: isPositiveHabit ? "xmark.circle.fill" : "exclamationmark.triangle.fill",
            background: Color.red.opacity(backgroundOpacity),
            foreground: .red
        )
    }
    
    private struct ButtonPalette {
        let fillColor: Color
    }
    
    private enum PrimaryActionStyle {
        case checkIn
        case resisted
        
        func palette(for scheme: ColorScheme) -> ButtonPalette {
            switch self {
            case .checkIn:
                let baseBlue = Color.blue
                return ButtonPalette(fillColor: baseBlue)
            case .resisted:
                let deepGreen = Color(red: 0.13, green: 0.55, blue: 0.13)
                return ButtonPalette(fillColor: deepGreen)
            }
        }
    }

}

// MARK: - Celebration Effect

private struct ConfettiEmitterView: UIViewRepresentable {
    let trigger: Int
    
    func makeUIView(context: Context) -> ConfettiHostView {
        ConfettiHostView()
    }
    
    func updateUIView(_ uiView: ConfettiHostView, context: Context) {
        guard context.coordinator.lastTrigger != trigger else { return }
        context.coordinator.lastTrigger = trigger
        uiView.emitOnce()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    final class Coordinator {
        var lastTrigger: Int = 0
    }
    
    final class ConfettiHostView: UIView {
        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .clear
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func emitOnce() {
            guard bounds.width > 0 else {
                DispatchQueue.main.async { [weak self] in
                    self?.emitOnce()
                }
                return
            }
            
            layer.sublayers?
                .filter { $0.name == "habit-confetti-layer" }
                .forEach { $0.removeFromSuperlayer() }
            
            let emitter = CAEmitterLayer()
            emitter.name = "habit-confetti-layer"
            emitter.emitterShape = .line
            emitter.emitterMode = .surface
            emitter.emitterPosition = CGPoint(x: bounds.midX, y: bounds.maxY)
            emitter.emitterSize = CGSize(width: bounds.width, height: 1)
            emitter.beginTime = CACurrentMediaTime()
            emitter.birthRate = 1
            
            emitter.emitterCells = ConfettiEmitterView.makeCells()
            layer.addSublayer(emitter)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                emitter.birthRate = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                emitter.removeFromSuperlayer()
            }
        }
    }
    
    private static func makeCells() -> [CAEmitterCell] {
        let colors: [UIColor] = [
            .systemGreen, .systemBlue, .systemPink, .systemYellow,
            .systemOrange, .systemPurple, .systemTeal
        ]
        return colors.flatMap { color -> [CAEmitterCell] in
            let square = baseCell(color: color)
            square.scale = 0.07
            square.scaleRange = 0.02
            
            let rectangle = baseCell(color: color)
            rectangle.scale = 0.08
            rectangle.scaleRange = 0.03
            rectangle.contents = UIImage(systemName: "rectangle.fill")?.cgImage
            
            return [square, rectangle]
        }
    }
    
    private static func baseCell(color: UIColor) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = UIImage(systemName: "circle.fill")?.cgImage
        cell.birthRate = 32
        cell.lifetime = 2.5
        cell.velocity = 220
        cell.velocityRange = 60
        cell.emissionLongitude = .pi / 2
        cell.emissionRange = .pi / 4
        cell.spin = 3.5
        cell.spinRange = 2
        cell.yAcceleration = 320
        cell.color = color.cgColor
        return cell
    }
}



private extension HabitCompletionLogDTO {
    func matchesLocalDay(dayKey: String) -> Bool {
        // Parse the date string and extract the date part using UTC formatter
        guard let logDate = DailyHabitsView.parseDate(date) else {
            #if DEBUG
            print("      ⚠️ matchesLocalDay: Failed to parse '\(date)', using prefix match")
            #endif
            return date.hasPrefix(dayKey) // Fallback to simple prefix match
        }
        let logKey = DailyHabitsView.utcDayKeyFormatter.string(from: logDate)
        let matches = logKey == dayKey
        #if DEBUG
        print("      🔍 matchesLocalDay: '\(date)' -> parsed: \(logDate) -> UTC key: '\(logKey)' vs dayKey: '\(dayKey)' = \(matches)")
        #endif
        return matches
    }
}


// MARK: - Palette

private enum DailyHabitsPalette {
    private static let blush = Color(uiColor: .systemPink).opacity(0.95)
    private static let lilac = Color(uiColor: .systemPurple).opacity(0.75)
    private static let periwinkle = Color(uiColor: .systemIndigo).opacity(0.6)
    private static let teal = Color(uiColor: .systemTeal).opacity(0.5)
    
    static func headerGradient(for colorScheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: gradientStops(for: colorScheme),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static func highlightGradient(for colorScheme: ColorScheme) -> LinearGradient {
        let leadingOpacity = colorScheme == .dark ? 0.18 : 0.45
        let trailingOpacity = colorScheme == .dark ? 0.05 : 0.15
        return LinearGradient(
            colors: [
                Color.white.opacity(leadingOpacity),
                Color.white.opacity(trailingOpacity),
                .clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static func glossOverlay(for colorScheme: ColorScheme) -> some View {
        let overlayOpacity = colorScheme == .dark ? 0.28 : 0.6
        let gradientOpacity = colorScheme == .dark ? 0.2 : 0.45
        
        return ZStack {
            RadialGradient(
                colors: [
                    Color.white.opacity(gradientOpacity),
                    Color.white.opacity(0.08),
                    .clear
                ],
                center: .topLeading,
                startRadius: 24,
                endRadius: 420
            )
            
            LinearGradient(
                colors: [
                    Color.white.opacity(colorScheme == .dark ? 0.2 : 0.35),
                    Color.white.opacity(colorScheme == .dark ? 0.04 : 0.05),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .blendMode(colorScheme == .dark ? .plusLighter : .screen)
        .opacity(overlayOpacity)
    }
    
    static func fadeOverlay(for colorScheme: ColorScheme) -> LinearGradient {
        let surface = surfaceBackground(for: colorScheme)
        let grouped = Color(.systemGroupedBackground)
        
        return LinearGradient(
            colors: [surface.opacity(0), grouped],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    static func cardBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(uiColor: .secondarySystemBackground) : Color(.systemBackground)
    }
    
    static func cardShadow(for colorScheme: ColorScheme) -> Color {
        Color.black.opacity(colorScheme == .dark ? 0.45 : 0.08)
    }
    
    private static func surfaceBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(uiColor: .secondarySystemBackground) : Color(.systemBackground)
    }
    
    private static func gradientStops(for colorScheme: ColorScheme) -> [Color] {
        if colorScheme == .dark {
            return [
                blush.opacity(0.65),
                lilac.opacity(0.5),
                periwinkle.opacity(0.45),
                teal.opacity(0.4)
            ]
        }
        return [blush, lilac, periwinkle, teal]
    }
}

