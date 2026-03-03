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
    @State private var lastLogsFetchDate: String?
    @State private var displayedHabits: [DailyHabitDTO] = []
    @State private var selectedHabitForDetail: DailyHabitDTO?
    @State private var selectedHabitForNotification: DailyHabitDTO?
    @State private var selectedHabitForPomodoro: DailyHabitDTO?
    @State private var selectedHabitForCompletion: (habit: DailyHabitDTO, actionType: HabitCompletionSheet.HabitActionType)?
    @State private var notificationUpdateTrigger = UUID()
    @State private var isBootstrappingHabits = true
    @State private var isPresentingFilters = false
    @State private var habitFilters = HabitFilters()
    
    private var habitsState: AppState.HabitsState { container.appState.state.habits }
    private var habitsInteractor: HabitsInteractor { container.interactors.habitsInteractor }
    private var backendUserId: String? { container.appState.state.auth.user?.id }
    
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = .current
        formatter.timeZone = .current
        return formatter
    }()
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            gradientLayer
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    progressHeader
                    habitsSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 130)
                .padding(.bottom, 48)
                .safeAreaPadding(.top, 0)
            }
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
                Button(action: { isPresentingFilters = true }) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.title3.weight(.semibold))
                }
                .accessibilityLabel("Filter Habits")
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
        .sheet(isPresented: $isPresentingFilters) {
            DailyHabitsFilterSheet(
                filters: $habitFilters,
                onUnarchive: handleUnarchive
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
        }
        .sheet(item: $selectedHabitForDetail) { habit in
            HabitViewSheet(
                habit: habit,
                completion: completionLog(for: habit),
                isPerformingAction: habitsState.pendingActionHabitId == habit.id,
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
            habitsInteractor.clearLocalCompletions()
_Concurrency.Task { await loadHabitsIfNeeded(force: true) }
        }
        .onChange(of: selectedDate) { _ in
            habitsInteractor.clearLocalCompletions()
_Concurrency.Task { await loadHabitsIfNeeded(force: true) }
        }
        .alert("Unable to update habit", isPresented: Binding(
            get: { habitsState.actionError != nil },
            set: { newValue in if !newValue { habitsInteractor.clearActionError() } })
        ) {
            Button("OK", role: .cancel) { habitsInteractor.clearActionError() }
        } message: {
            Text(habitsState.actionError ?? "")
        }
    }
    
    @State private var pillsAppeared = false

    private var habitsDone: Int { filteredHabits.filter { completionLog(for: $0) != nil && !(completionLog(for: $0)?.wasSkipped ?? false) }.count }
    private var habitsTotal: Int { filteredHabits.count }
    private var habitsSkipped: Int { filteredHabits.filter { completionLog(for: $0)?.wasSkipped ?? false }.count }
    private var habitsPending: Int { filteredHabits.filter { completionLog(for: $0) == nil }.count }
    private var streakCount: Int { filteredHabits.filter { ($0.currentStreak ?? 0) > 0 }.count }

    private var progressHeader: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
            habitPill(value: habitsTotal, label: "Total", icon: "square.grid.2x2.fill", color: .blue, delay: 0)
            habitPill(value: habitsDone, label: "Done", icon: "checkmark.circle.fill", color: .green, delay: 0.05)
            habitPill(value: habitsSkipped, label: "Skipped", icon: "forward.fill", color: .orange, delay: 0.1)
            habitPill(value: habitsPending, label: "Pending", icon: "clock.fill", color: .purple, delay: 0.15)
            habitPill(value: streakCount, label: "Streaks", icon: "flame.fill", color: .red, delay: 0.2)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(DailyHabitsPalette.cardBackground(for: colorScheme))
                .shadow(color: DailyHabitsPalette.cardShadow(for: colorScheme), radius: 6, y: 3)
        )
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.1)) { pillsAppeared = true }
        }
    }

    private func habitPill(value: Int, label: String, icon: String, color: Color, delay: Double) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(color)
            Text("\(value)")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText(value: Double(value)))
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color.opacity(colorScheme == .dark ? 0.1 : 0.06))
        )
        .scaleEffect(pillsAppeared ? 1 : 0.7)
        .opacity(pillsAppeared ? 1 : 0)
        .animation(.spring(response: 0.45, dampingFraction: 0.7).delay(delay), value: pillsAppeared)
    }
    
    private var filteredHabits: [DailyHabitDTO] {
        displayedHabits.filter { habit in
            // Filter by habit type
            if let typeFilter = habitFilters.habitType {
                let isPositive = habit.isPositive ?? true
                if typeFilter == .build && !isPositive { return false }
                if typeFilter == .breakHabit && isPositive { return false }
            }
            
            // Filter by priority
            if let priorityFilter = habitFilters.priority {
                guard let habitPriority = habit.priority?.lowercased() else { return false }
                if habitPriority != priorityFilter.rawValue { return false }
            }
            
            // Filter by category
            if let categoryFilter = habitFilters.category, !categoryFilter.isEmpty {
                guard let habitCategory = habit.category?.lowercased() else { return false }
                if habitCategory != categoryFilter.lowercased() { return false }
            }
            
            return true
        }
    }
    
    @ViewBuilder
    private var habitsSection: some View {
        if shouldShowInitialLoader || habitsState.isLoading {
            habitsLoadingView
        } else if let error = habitsState.error {
            habitsErrorView(error)
        } else if filteredHabits.isEmpty {
            if displayedHabits.isEmpty {
                habitsEmptyView
            } else {
                noMatchingFiltersView
            }
        } else {
            VStack(spacing: 10) {
                ForEach(filteredHabits) { habit in
                    HabitRow(
                        habit: habit,
                        completion: completionLog(for: habit),
                        isPerformingAction: habitsState.pendingActionHabitId == habit.id,
                        onAction: handleHabitAction,
                        onSelect: { selectedHabitForDetail = $0 },
                        onArchive: handleArchive,
                        onEdit: { selectedHabitForDetail = $0 },
                        onNotification: { selectedHabitForNotification = $0 },
                        onPomodoro: { selectedHabitForPomodoro = $0 },
                        notificationUpdateTrigger: notificationUpdateTrigger
                    )
                }
            }
        }
    }
    
    private var noMatchingFiltersView: some View {
        VStack(spacing: 12) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No matching habits")
                .font(.headline)
            Text("Try adjusting your filters to see more habits.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                habitFilters = HabitFilters()
            } label: {
                Text("Clear Filters")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(cardBackground)
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
_Concurrency.Task { await loadHabitsIfNeeded(force: true) }
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
    
    // MARK: - Business Logic Delegation
    
    private func loadHabitsIfNeeded(force: Bool = false) async {
        guard let userId = backendUserId else {
            await MainActor.run {
                isBootstrappingHabits = false
            }
            return
        }
        
        let dateString = Self.dayFormatter.string(from: selectedDate)
        let signature = "\(userId)|\(dateString)"
        let needsLogsFetch = force || lastLogsFetchDate != dateString
        
        guard force || lastLoadedSignature != signature || habitsState.habits.isEmpty else {
            await MainActor.run {
                displayedHabits = habitsState.habits
                isBootstrappingHabits = false
            }
            return
        }
        
        lastLoadedSignature = signature
        await habitsInteractor.loadHabits(for: selectedDate)
        
        if needsLogsFetch {
            await habitsInteractor.loadCompletionLogs(for: selectedDate)
            await MainActor.run {
                lastLogsFetchDate = dateString
            }
        }
        
        await MainActor.run {
            displayedHabits = habitsState.habits
            
            // Refresh the detail sheet if open
            if let detailHabit = selectedHabitForDetail,
               let refreshed = displayedHabits.first(where: { $0.id == detailHabit.id }) {
                selectedHabitForDetail = refreshed
            }
            isBootstrappingHabits = false
        }
    }

    private func handleHabitAction(_ action: HabitAction) {
        guard habitsState.pendingActionHabitId == nil else { return }
        
        // For SKIP and FAILED actions, show the completion sheet
        switch action {
        case .skipDay(let habit):
            selectedHabitForCompletion = (habit, .skip)
            return
        case .failedToResist(let habit):
            selectedHabitForCompletion = (habit, .failedToResist)
            return
        case .checkIn, .resisted:
            break
        }
        
_Concurrency.Task {
            await habitsInteractor.performHabitAction(action, for: selectedDate)
            
            // Update displayed habits
            await MainActor.run {
                displayedHabits = habitsState.habits
                if let detailHabit = selectedHabitForDetail,
                   let updated = habitsState.habits.first(where: { $0.id == detailHabit.id }) {
                    selectedHabitForDetail = updated
                }
            }
        }
    }
    
    private func handleCompletionSubmit(habit: DailyHabitDTO, data: HabitCompletionData) {
        guard let userId = backendUserId else {
            habitsInteractor.clearActionError()
            return
        }
        
_Concurrency.Task {
            let localCalendar = Calendar.current
            let dayStartLocal = localCalendar.startOfDay(for: selectedDate)
            
            let localDateFormatter = DateFormatter()
            localDateFormatter.dateFormat = "yyyy-MM-dd"
            localDateFormatter.timeZone = localCalendar.timeZone
            let dateString = localDateFormatter.string(from: dayStartLocal) + "T00:00:00.000Z"
            
            let isoDateFormatter = ISO8601DateFormatter()
            isoDateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            isoDateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
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
            
            // Create a temporary action to use the interactor
            let action: HabitAction = data.wasSkipped ? .skipDay(habit) : (data.completed ? .checkIn(habit) : .failedToResist(habit))
            
            await habitsInteractor.performHabitAction(action, for: selectedDate)
            
            await MainActor.run {
                displayedHabits = habitsState.habits
                if let detailHabit = selectedHabitForDetail,
                   let updated = habitsState.habits.first(where: { $0.id == detailHabit.id }) {
                    selectedHabitForDetail = updated
                }
            }
        }
    }

    private func handleArchive(_ habit: DailyHabitDTO) {
        guard habitsState.pendingActionHabitId == nil else { return }

        _Concurrency.Task {
            await habitsInteractor.toggleArchive(for: habit)
            await MainActor.run {
                displayedHabits = habitsState.habits
                if let detailHabit = selectedHabitForDetail,
                   let updated = habitsState.habits.first(where: { $0.id == detailHabit.id }) {
                    selectedHabitForDetail = updated
                } else if selectedHabitForDetail?.id == habit.id {
                    selectedHabitForDetail = nil
                }
            }
        }
    }
    
    private func handleUnarchive(_ habit: DailyHabitDTO) {
        _Concurrency.Task {
            await habitsInteractor.toggleArchive(for: habit)
            await MainActor.run {
                displayedHabits = habitsState.habits
            }
        }
    }

    private func completionLog(for habit: DailyHabitDTO) -> HabitCompletionLogDTO? {
        let dayKey = Self.dayFormatter.string(from: selectedDate)
        
        // Check local completions first
        if let override = habitsState.localCompletions[habit.id],
           matchesLocalDay(override.date, dayKey: dayKey) {
            return override
        }
        
        // Check habit logs
        guard let logs = habit.completionLogs else { return nil }
        return logs.first(where: { log in
            guard let logDate = Self.parseDate(log.date) else { return false }
            let logKey = Self.utcDayKeyFormatter.string(from: logDate)
            return logKey == dayKey
        })
    }
    
    private func matchesLocalDay(_ dateString: String, dayKey: String) -> Bool {
        guard let logDate = Self.parseDate(dateString) else {
            return dateString.hasPrefix(dayKey)
        }
        let logKey = Self.utcDayKeyFormatter.string(from: logDate)
        return logKey == dayKey
    }

    private func handleBackAction() {
        if tabBar.config == .dailyHabits {
            tabBar.config = .default
        } else {
            dismiss()
        }
    }
}

// MARK: - Date Utilities

private extension DailyHabitsView {
    static let utcDayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
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
}

// MARK: - Habit Card

private struct HabitRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let habit: DailyHabitDTO
    let completion: HabitCompletionLogDTO?
    let isPerformingAction: Bool
    let onAction: (HabitAction) -> Void
    let onSelect: (DailyHabitDTO) -> Void
    let onArchive: (DailyHabitDTO) -> Void
    let onEdit: (DailyHabitDTO) -> Void
    let onNotification: (DailyHabitDTO) -> Void
    let onPomodoro: (DailyHabitDTO) -> Void
    let notificationUpdateTrigger: UUID

    @State private var celebrationTrigger = 0
    @State private var notificationCount: Int = 0
    @State private var dragOffset: CGFloat = 0
    @State private var swipeDirection: SwipeDirection = .none

    private let swipeThreshold: CGFloat = 50
    private let swipeOpenWidth: CGFloat = 72
    private enum SwipeDirection { case none, left, right }

    private var isPositive: Bool { habit.isPositive ?? true }
    private var isActionDisabled: Bool { isPerformingAction || completion != nil }

    private var state: Done {
        guard let completion else { return .pending }
        if completion.wasSkipped ?? false { return .skipped }
        return completion.completed ? .done : .failed
    }
    private enum Done { case pending, done, skipped, failed }

    private var pColor: Color {
        switch habit.priority?.lowercased() {
        case "high": return .red
        case "medium": return .orange
        default: return .blue
        }
    }
    private var pSymbol: String {
        switch habit.priority?.lowercased() {
        case "high": return "exclamationmark.3"
        case "medium": return "exclamationmark.2"
        default: return "exclamationmark"
        }
    }

    // MARK: Body

    var body: some View {
        ZStack {
            swipeArchiveLayer
            swipeEditLayer
            card
                .offset(x: dragOffset)
                .gesture(dragGesture)
                .onTapGesture { handleTap() }
        }
        .clipped()
        .onAppear { loadNotificationCount() }
        .onChange(of: notificationUpdateTrigger) { _ in loadNotificationCount() }
    }

    // MARK: - Card Layout

    private var card: some View {
        VStack(spacing: 0) {
            topRow
            bottomRow
        }
        .padding(14)
        .background(cardSurface)
        .overlay(alignment: .top) {
            ConfettiEmitterView(trigger: celebrationTrigger)
                .frame(height: 120)
                .offset(y: -10)
                .allowsHitTesting(false)
        }
    }

    // ── Row 1: Priority icon · Name · Streak · Timer · Bell ──

    private var topRow: some View {
        HStack(spacing: 10) {
            priorityAvatar
            nameLabel
            Spacer(minLength: 0)
            streakPill
            toolbarIcons
        }
    }

    // ── Row 2: Meta tags · Action circles ──

    private var bottomRow: some View {
        HStack(spacing: 0) {
            metaTags
            Spacer(minLength: 0)
            actionCircles
        }
        .padding(.top, 10)
    }

    // MARK: - Priority Avatar

    private var priorityAvatar: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            pColor.opacity(colorScheme == .dark ? 0.32 : 0.18),
                            pColor.opacity(colorScheme == .dark ? 0.1 : 0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Circle()
                        .strokeBorder(pColor.opacity(state == .done ? 0.6 : 0.18), lineWidth: state == .done ? 2 : 1)
                )

            Image(systemName: pSymbol)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(pColor)
                .scaleEffect(state == .done ? 1.12 : 1)
                .animation(.spring(response: 0.4, dampingFraction: 0.55), value: state)
        }
        .frame(width: 40, height: 40)
        .shadow(color: state == .done ? pColor.opacity(0.25) : .clear, radius: 5, y: 2)
        .animation(.easeInOut(duration: 0.25), value: state)
    }

    // MARK: - Name

    private var nameLabel: some View {
        Text(habit.name)
            .font(.system(size: 15, weight: .semibold))
            .lineLimit(1)
            .foregroundStyle(.primary)
    }

    // MARK: - Streak Pill

    @ViewBuilder
    private var streakPill: some View {
        if let s = habit.currentStreak, s > 0 {
            HStack(spacing: 3) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 10))
                Text("\(s)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.orange)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.orange.opacity(colorScheme == .dark ? 0.15 : 0.08), in: Capsule())
        }
    }

    // MARK: - Toolbar Icons (Robinhood style)

    private var toolbarIcons: some View {
        HStack(spacing: 14) {
            Button { onPomodoro(habit) } label: {
                Image(systemName: "timer")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(Color(.label).opacity(0.35))
            }
            .buttonStyle(.plain)

            Button { onNotification(habit) } label: {
                Image(systemName: "bell")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(Color(.label).opacity(0.35))
                    .overlay(alignment: .topTrailing) {
                        if notificationCount > 0 {
                            Circle().fill(Color.green)
                                .frame(width: 5, height: 5)
                                .offset(x: 2, y: -1)
                        }
                    }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Meta Tags

    private var metaTags: some View {
        HStack(spacing: 8) {
            HStack(spacing: 3) {
                Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 8, weight: .bold))
                Text(isPositive ? "Build" : "Break")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(isPositive ? .green : .red)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background((isPositive ? Color.green : Color.red).opacity(colorScheme == .dark ? 0.15 : 0.08), in: Capsule())

            Text((habit.frequency ?? "daily").replacingOccurrences(of: "_", with: " ").capitalized)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color(.quaternarySystemFill), in: Capsule())

            if let cat = habit.category, !cat.isEmpty {
                Text(cat)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color(.quaternarySystemFill), in: Capsule())
            }
        }
    }

    // MARK: - Action Circles

    @ViewBuilder
    private var actionCircles: some View {
        if isPerformingAction {
            ProgressView()
                .scaleEffect(0.7)
                .frame(width: 36, height: 36)
        } else {
            HStack(spacing: 8) {
                actionCircle(
                    icon: isPositive ? "forward.fill" : "xmark",
                    color: isPositive ? .orange : .red,
                    isSelected: state == .skipped || state == .failed,
                    dimmed: state == .done
                ) {
                    guard !isActionDisabled else { return }
                    onAction(isPositive ? .skipDay(habit) : .failedToResist(habit))
                }

                actionCircle(
                    icon: isPositive ? "checkmark" : "shield.checkered",
                    color: .green,
                    isSelected: state == .done,
                    dimmed: state == .skipped || state == .failed
                ) {
                    guard !isActionDisabled else { return }
                    celebrationTrigger &+= 1
                    onAction(isPositive ? .checkIn(habit) : .resisted(habit))
                }
            }
        }
    }

    private func actionCircle(
        icon: String,
        color: Color,
        isSelected: Bool,
        dimmed: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(isSelected ? .white : color)
                .frame(width: 36, height: 36)
                .background(
                    Circle().fill(isSelected ? color : color.opacity(colorScheme == .dark ? 0.18 : 0.1))
                )
                .overlay(
                    Circle().strokeBorder(color.opacity(isSelected ? 0 : 0.3), lineWidth: 1.5)
                )
                .scaleEffect(isSelected ? 1.1 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.55), value: isSelected)
        }
        .buttonStyle(.plain)
        .disabled(isActionDisabled)
        .opacity(dimmed ? 0.3 : 1)
    }

    // MARK: - Card Surface

    private var cardSurface: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(DailyHabitsPalette.cardBackground(for: colorScheme))
            .shadow(
                color: state == .done
                    ? Color.green.opacity(colorScheme == .dark ? 0.2 : 0.1)
                    : DailyHabitsPalette.cardShadow(for: colorScheme),
                radius: state == .done ? 10 : 6,
                y: 3
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        state == .done
                            ? Color.green.opacity(colorScheme == .dark ? 0.3 : 0.15)
                            : Color(.separator).opacity(colorScheme == .dark ? 0.15 : 0.08),
                        lineWidth: 1
                    )
            )
    }

    // MARK: - Swipe Actions

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onChanged { v in
                var base: CGFloat = 0
                if swipeDirection == .right { base = swipeOpenWidth }
                else if swipeDirection == .left { base = -swipeOpenWidth }
                dragOffset = max(-swipeOpenWidth - 30, min(base + v.translation.width, swipeOpenWidth + 30))
            }
            .onEnded { v in
                let vel = v.predictedEndTranslation.width - v.translation.width
                let openR = dragOffset > swipeThreshold / 2 || (dragOffset > 0 && vel > 100)
                let openL = dragOffset < -swipeThreshold / 2 || (dragOffset < 0 && vel < -100)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    if openR { dragOffset = swipeOpenWidth; swipeDirection = .right }
                    else if openL { dragOffset = -swipeOpenWidth; swipeDirection = .left }
                    else { dragOffset = 0; swipeDirection = .none }
                }
            }
    }

    private var swipeArchiveLayer: some View {
        HStack {
            Button { fireSwipe(archive: true) } label: {
                Image(systemName: "archivebox.fill")
                    .font(.body.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(width: swipeOpenWidth)
                    .frame(maxHeight: .infinity)
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.orange))
        .opacity(dragOffset > 0 ? min(dragOffset / 30, 1) : 0)
    }

    private var swipeEditLayer: some View {
        HStack {
            Spacer()
            Button { fireSwipe(archive: false) } label: {
                Image(systemName: "pencil")
                    .font(.body.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(width: swipeOpenWidth)
                    .frame(maxHeight: .infinity)
            }
            .buttonStyle(.plain)
        }
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.blue))
        .opacity(dragOffset < 0 ? min(abs(dragOffset) / CGFloat(30), 1) : 0)
    }

    private func fireSwipe(archive: Bool) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            dragOffset = 0; swipeDirection = .none
        }
        archive ? onArchive(habit) : onEdit(habit)
    }

    private func handleTap() {
        if swipeDirection != .none {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                dragOffset = 0; swipeDirection = .none
            }
        } else { onSelect(habit) }
    }

    private func loadNotificationCount() {
        notificationCount = (UserDefaults.standard.array(forKey: "notifications_\(habit.id)") as? [Date])?.count ?? 0
    }
}

// MARK: - Habit Filters Model

struct HabitFilters: Equatable {
    var habitType: HabitType?
    var priority: Priority?
    var category: String?
    
    enum HabitType: String, CaseIterable {
        case build = "build"
        case breakHabit = "break"
        
        var displayName: String {
            switch self {
            case .build: return "Build"
            case .breakHabit: return "Break"
            }
        }
        
        var icon: String {
            switch self {
            case .build: return "arrow.up.circle.fill"
            case .breakHabit: return "arrow.down.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .build: return .green
            case .breakHabit: return .red
            }
        }
    }
    
    enum Priority: String, CaseIterable {
        case high = "high"
        case medium = "medium"
        case low = "low"
        
        var displayName: String { rawValue.capitalized }
        
        var color: Color {
            switch self {
            case .high: return .red
            case .medium: return .orange
            case .low: return .blue
            }
        }
    }
    
    var hasActiveFilters: Bool {
        habitType != nil || priority != nil || (category != nil && !category!.isEmpty)
    }
}

// MARK: - Filter Sheet

private struct DailyHabitsFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.injected) private var container: DIContainer
    
    @Binding var filters: HabitFilters
    let onUnarchive: (DailyHabitDTO) -> Void
    
    @State private var archivedHabits: [DailyHabitDTO] = []
    @State private var isLoadingArchived = false
    @State private var isArchivedExpanded = false
    
    var body: some View {
        NavigationStack {
            Form {
                // Filters Section
                Section {
                    Picker("Habit Type", selection: $filters.habitType) {
                        Text("All").tag(HabitFilters.HabitType?.none)
                        ForEach(HabitFilters.HabitType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(HabitFilters.HabitType?.some(type))
                        }
                    }
                    
                    Picker("Priority", selection: $filters.priority) {
                        Text("All").tag(HabitFilters.Priority?.none)
                        ForEach(HabitFilters.Priority.allCases, id: \.self) { priority in
                            Text(priority.displayName)
                                .tag(HabitFilters.Priority?.some(priority))
                        }
                    }
                } header: {
                    Text("Filter By")
                } footer: {
                    if filters.hasActiveFilters {
                        Button("Clear All Filters") {
                            filters = HabitFilters()
                        }
                    }
                }
                
                // Archived Habits Section
                Section {
                    DisclosureGroup(isExpanded: $isArchivedExpanded) {
                        if isLoadingArchived {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else if archivedHabits.isEmpty {
                            ContentUnavailableView {
                                Label("No Archived Habits", systemImage: "archivebox")
                            } description: {
                                Text("Archived habits will appear here")
                            }
                        } else {
                            ForEach(archivedHabits) { habit in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(habit.name)
                                        
                                        HStack(spacing: 4) {
                                            Image(systemName: (habit.isPositive ?? true) ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                                .foregroundStyle((habit.isPositive ?? true) ? .green : .red)
                                            
                                            Text((habit.isPositive ?? true) ? "Build" : "Break")
                                            
                                            if let priority = habit.priority {
                                                Text("•")
                                                Text(priority.capitalized)
                                            }
                                        }
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Button("Restore") {
                                        unarchiveHabit(habit)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                        }
                    } label: {
                        Label("Archived Habits", systemImage: "archivebox.fill")
                    }
                    .onChange(of: isArchivedExpanded) { _, expanded in
                        if expanded && archivedHabits.isEmpty {
                            loadArchivedHabits()
                        }
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func loadArchivedHabits() {
        isLoadingArchived = true
        
        _Concurrency.Task {
            let habits = await container.interactors.habitsInteractor.loadArchivedHabits()
            await MainActor.run {
                archivedHabits = habits
                isLoadingArchived = false
            }
        }
    }
    
    private func unarchiveHabit(_ habit: DailyHabitDTO) {
        withAnimation {
            archivedHabits.removeAll { $0.id == habit.id }
        }
        onUnarchive(habit)
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
