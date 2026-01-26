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
    @State private var showFullInsight = false
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
                VStack(alignment: .leading, spacing: 16) {
                    headerPlaceholder
                    habitsSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
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
            VStack(spacing: 16) {
                ForEach(filteredHabits) { habit in
                    HabitCardView(
                        habit: habit,
                        completion: completionLog(for: habit),
                        isPerformingAction: habitsState.pendingActionHabitId == habit.id,
                        onAction: handleHabitAction,
                        onNotification: { selectedHabitForNotification = $0 },
                        onPomodoro: { selectedHabitForPomodoro = $0 },
                        onSelect: { selectedHabitForDetail = $0 },
                        onArchive: handleArchive,
                        onEdit: { selectedHabitForDetail = $0 },
                        notificationUpdateTrigger: notificationUpdateTrigger
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
    let onArchive: (DailyHabitDTO) -> Void
    let onEdit: (DailyHabitDTO) -> Void
    let notificationUpdateTrigger: UUID
    let extraContent: AnyView?
    @State private var celebrationTrigger = 0
    @State private var notificationCount: Int = 0
    @State private var dragOffset: CGFloat = 0
    @State private var swipeDirection: SwipeDirection = .none
    
    private let swipeThreshold: CGFloat = 60
    private let swipeOpenWidth: CGFloat = 80
    
    private enum SwipeDirection {
        case none, left, right
    }
    
    init(
        habit: DailyHabitDTO,
        completion: HabitCompletionLogDTO?,
        isPerformingAction: Bool,
        onAction: @escaping (HabitAction) -> Void,
        onNotification: @escaping (DailyHabitDTO) -> Void,
        onPomodoro: @escaping (DailyHabitDTO) -> Void,
        onSelect: @escaping (DailyHabitDTO) -> Void,
        onArchive: @escaping (DailyHabitDTO) -> Void,
        onEdit: @escaping (DailyHabitDTO) -> Void,
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
        self.onArchive = onArchive
        self.onEdit = onEdit
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
        ZStack {
            // Archive action revealed when swiping right
            archiveActionBackground
            
            // Edit action revealed when swiping left
            editActionBackground
            
            // Main card content
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
            .offset(x: dragOffset)
            .gesture(
                DragGesture(minimumDistance: 20, coordinateSpace: .local)
                    .onChanged { value in
                        handleDragChanged(value)
                    }
                    .onEnded { value in
                        handleDragEnded(value)
                    }
            )
            .onTapGesture {
                if swipeDirection != .none {
                    // Close the swipe action
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        dragOffset = 0
                        swipeDirection = .none
                    }
                } else if dragOffset == 0 {
                    onSelect(habit)
                }
            }
        }
        .clipped()
    }
    
    private var archiveActionBackground: some View {
        HStack(spacing: 0) {
            Button {
                triggerArchive()
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: "archivebox.fill")
                        .font(.title2.weight(.semibold))
                    Text("Archive")
                        .font(.caption.weight(.semibold))
                }
                .foregroundColor(.white)
                .frame(width: swipeOpenWidth)
                .frame(maxHeight: .infinity)
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color.orange, Color.orange.opacity(0.8)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(16)
        .opacity(dragOffset > 0 ? min(dragOffset / 40, 1.0) : 0)
    }
    
    private var editActionBackground: some View {
        HStack(spacing: 0) {
            Spacer()
            
            Button {
                triggerEdit()
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: "pencil")
                        .font(.title2.weight(.semibold))
                    Text("Edit")
                        .font(.caption.weight(.semibold))
                }
                .foregroundColor(.white)
                .frame(width: swipeOpenWidth)
                .frame(maxHeight: .infinity)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.8), Color.blue],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(16)
        .opacity(dragOffset < 0 ? min(abs(dragOffset) / 40, 1.0) : 0)
    }
    
    private func triggerArchive() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            dragOffset = 0
            swipeDirection = .none
        }
        onArchive(habit)
    }
    
    private func triggerEdit() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            dragOffset = 0
            swipeDirection = .none
        }
        onEdit(habit)
    }
    
    private func handleDragChanged(_ value: DragGesture.Value) {
        let horizontal = value.translation.width
        
        // Calculate offset based on current swipe direction
        var startOffset: CGFloat = 0
        if swipeDirection == .right {
            startOffset = swipeOpenWidth
        } else if swipeDirection == .left {
            startOffset = -swipeOpenWidth
        }
        
        let newOffset = startOffset + horizontal
        
        // Clamp to max swipe range in both directions
        dragOffset = max(-swipeOpenWidth - 40, min(newOffset, swipeOpenWidth + 40))
    }
    
    private func handleDragEnded(_ value: DragGesture.Value) {
        let velocity = value.predictedEndTranslation.width - value.translation.width
        
        // Determine if we should open right (Archive)
        let shouldOpenRight = dragOffset > swipeThreshold / 2 || (dragOffset > 0 && velocity > 100)
        
        // Determine if we should open left (Edit)
        let shouldOpenLeft = dragOffset < -swipeThreshold / 2 || (dragOffset < 0 && velocity < -100)
        
        if shouldOpenRight && swipeDirection != .right {
            // Snap open right with haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                dragOffset = swipeOpenWidth
                swipeDirection = .right
            }
        } else if shouldOpenLeft && swipeDirection != .left {
            // Snap open left with haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                dragOffset = -swipeOpenWidth
                swipeDirection = .left
            }
        } else if !shouldOpenRight && !shouldOpenLeft {
            // Snap closed
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                dragOffset = 0
                swipeDirection = .none
            }
        } else if swipeDirection == .right {
            // Keep right open
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                dragOffset = swipeOpenWidth
            }
        } else if swipeDirection == .left {
            // Keep left open
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                dragOffset = -swipeOpenWidth
            }
        }
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
                return ButtonPalette(fillColor: .blue)
            case .resisted:
                let deepGreen = Color(red: 0.13, green: 0.55, blue: 0.13)
                return ButtonPalette(fillColor: deepGreen)
            }
        }
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
