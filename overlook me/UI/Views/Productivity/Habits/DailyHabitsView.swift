import SwiftUI
#if canImport(QuartzCore)
import QuartzCore
#endif
#if canImport(UIKit)
import UIKit
#endif

// kalSegment is kalInput in the shared token file — alias here for backward compat
private extension Color {
    static let kalSegment = Color.kalInput
}

// MARK: - DailyHabitsView

struct DailyHabitsView: View {
    @Environment(\.dismiss) private var dismiss
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
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.calendar = .current
        f.timeZone = .current
        return f
    }()

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                statsHeader
                habitsSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 48)
        }
        .background(Color.kalBackground.ignoresSafeArea())
        .navigationTitle("Daily Habits")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar { toolbarContent }
        .refreshable { await loadHabitsIfNeeded(force: true) }
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
            set: { if !$0 { habitsInteractor.clearActionError() } }
        )) {
            Button("OK", role: .cancel) { habitsInteractor.clearActionError() }
        } message: {
            Text(habitsState.actionError ?? "")
        }
        .sheet(isPresented: $isPresentingAddHabit) {
            AddNewHabitView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isPresentingFilters) {
            DailyHabitsFilterSheet(filters: $habitFilters, onUnarchive: handleUnarchive)
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
                    onCancel: { selectedHabitForCompletion = nil }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(action: handleBackAction) {
                Label("Back", systemImage: "chevron.left")
                    .labelStyle(.titleAndIcon)
                    .font(.body.weight(.semibold))
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button { isPresentingFilters = true } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.title3.weight(.semibold))
            }
            .accessibilityLabel("Filter Habits")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button { isPresentingAddHabit = true } label: {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
            }
            .accessibilityLabel("Add Habit")
        }
    }

    // MARK: - Stats Header

    private var habitsDone: Int    { filteredHabits.filter { completionLog(for: $0) != nil && !(completionLog(for: $0)?.wasSkipped ?? false) }.count }
    private var habitsTotal: Int   { filteredHabits.count }
    private var habitsSkipped: Int { filteredHabits.filter { completionLog(for: $0)?.wasSkipped ?? false }.count }
    private var habitsPending: Int { filteredHabits.filter { completionLog(for: $0) == nil }.count }
    private var streakCount: Int   { filteredHabits.filter { ($0.currentStreak ?? 0) > 0 }.count }

    private var statsHeader: some View {
        HStack(spacing: 0) {
            statCell(value: habitsTotal,   label: "Total")
            statSeparator
            statCell(value: habitsDone,    label: "Done")
            statSeparator
            statCell(value: habitsSkipped, label: "Skipped")
            statSeparator
            statCell(value: habitsPending, label: "Pending")
            statSeparator
            statCell(value: streakCount,   label: "Streaks")
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.kalSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.kalBorder, lineWidth: 1)
                )
        )
    }

    private func statCell(value: Int, label: String) -> some View {
        VStack(spacing: 3) {
            Text("\(value)")
                .font(.system(size: 20, weight: .bold))
                .tracking(-0.8)
                .foregroundStyle(Color.kalPrimary)
                .contentTransition(.numericText(value: Double(value)))
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.54)
                .foregroundStyle(Color.kalTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var statSeparator: some View {
        Rectangle()
            .fill(Color.kalDivider)
            .frame(width: 1, height: 26)
    }

    // MARK: - Habits Section

    private var filteredHabits: [DailyHabitDTO] {
        displayedHabits.filter { habit in
            if let typeFilter = habitFilters.habitType {
                let isPositive = habit.isPositive ?? true
                if typeFilter == .build && !isPositive { return false }
                if typeFilter == .breakHabit && isPositive { return false }
            }
            if let priorityFilter = habitFilters.priority {
                guard let p = habit.priority?.lowercased() else { return false }
                if p != priorityFilter.rawValue { return false }
            }
            if let categoryFilter = habitFilters.category, !categoryFilter.isEmpty {
                guard let c = habit.category?.lowercased() else { return false }
                if c != categoryFilter.lowercased() { return false }
            }
            return true
        }
    }

    @ViewBuilder
    private var habitsSection: some View {
        if shouldShowInitialLoader || (habitsState.isLoading && displayedHabits.isEmpty) {
            loadingView
        } else if let error = habitsState.error {
            errorView(error)
        } else if filteredHabits.isEmpty {
            if displayedHabits.isEmpty { emptyView } else { noMatchView }
        } else {
            VStack(spacing: 8) {
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

    private var shouldShowInitialLoader: Bool { isBootstrappingHabits && displayedHabits.isEmpty }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading habits…")
                .font(.system(size: 13))
                .foregroundStyle(Color.kalMuted)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
    }

    private func errorView(_ error: Error) -> some View {
        stateCard {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundStyle(Color.orange)
            Text("Unable to load habits")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.kalPrimary)
            Text(error.localizedDescription)
                .font(.system(size: 13))
                .foregroundStyle(Color.kalMuted)
                .multilineTextAlignment(.center)
            Button {
                _Concurrency.Task { await loadHabitsIfNeeded(force: true) }
            } label: {
                Text("Retry")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Color.kalPrimary, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var emptyView: some View {
        stateCard {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 36))
                .foregroundStyle(Color.kalTertiary)
            Text("No habits yet")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.kalPrimary)
            Text("Build your first habit to see it here.")
                .font(.system(size: 13))
                .foregroundStyle(Color.kalMuted)
            Button { isPresentingAddHabit = true } label: {
                Label("Create Habit", systemImage: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Color.kalPrimary, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var noMatchView: some View {
        stateCard {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 36))
                .foregroundStyle(Color.kalTertiary)
            Text("No matching habits")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.kalPrimary)
            Text("Try adjusting your filters.")
                .font(.system(size: 13))
                .foregroundStyle(Color.kalMuted)
            Button { habitFilters = HabitFilters() } label: {
                Text("Clear Filters")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Color.kalPrimary, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func stateCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 12) {
            content()
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.kalSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.kalBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Business Logic

    private func loadHabitsIfNeeded(force: Bool = false) async {
        guard let userId = backendUserId else {
            await MainActor.run { isBootstrappingHabits = false }
            return
        }
        let dateString = Self.dayFormatter.string(from: selectedDate)
        let signature  = "\(userId)|\(dateString)"
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
            await MainActor.run { lastLogsFetchDate = dateString }
        }

        await MainActor.run {
            displayedHabits = habitsState.habits
            if let detail = selectedHabitForDetail,
               let refreshed = displayedHabits.first(where: { $0.id == detail.id }) {
                selectedHabitForDetail = refreshed
            }
            isBootstrappingHabits = false
        }
    }

    private func handleHabitAction(_ action: HabitAction) {
        guard habitsState.pendingActionHabitId == nil else { return }
        switch action {
        case .skipDay(let habit):        selectedHabitForCompletion = (habit, .skip); return
        case .failedToResist(let habit): selectedHabitForCompletion = (habit, .failedToResist); return
        case .checkIn, .resisted: break
        }
        _Concurrency.Task {
            await habitsInteractor.performHabitAction(action, for: selectedDate)
            await MainActor.run {
                displayedHabits = habitsState.habits
                if let detail = selectedHabitForDetail,
                   let updated = habitsState.habits.first(where: { $0.id == detail.id }) {
                    selectedHabitForDetail = updated
                }
            }
        }
    }

    private func handleCompletionSubmit(habit: DailyHabitDTO, data: HabitCompletionData) {
        guard backendUserId != nil else { habitsInteractor.clearActionError(); return }
        _Concurrency.Task {
            let action: HabitAction = data.wasSkipped
                ? .skipDay(habit)
                : (data.completed ? .checkIn(habit) : .failedToResist(habit))
            await habitsInteractor.performHabitAction(action, for: selectedDate)
            await MainActor.run {
                displayedHabits = habitsState.habits
                if let detail = selectedHabitForDetail,
                   let updated = habitsState.habits.first(where: { $0.id == detail.id }) {
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
                if selectedHabitForDetail?.id == habit.id { selectedHabitForDetail = nil }
            }
        }
    }

    private func handleUnarchive(_ habit: DailyHabitDTO) {
        _Concurrency.Task {
            await habitsInteractor.toggleArchive(for: habit)
            await MainActor.run { displayedHabits = habitsState.habits }
        }
    }

    private func completionLog(for habit: DailyHabitDTO) -> HabitCompletionLogDTO? {
        let dayKey = Self.dayFormatter.string(from: selectedDate)
        if let override = habitsState.localCompletions[habit.id],
           matchesLocalDay(override.date, dayKey: dayKey) { return override }
        guard let logs = habit.completionLogs else { return nil }
        return logs.first(where: { log in
            guard let logDate = Self.parseDate(log.date) else { return false }
            return Self.utcDayKeyFormatter.string(from: logDate) == dayKey
        })
    }

    private func matchesLocalDay(_ dateString: String, dayKey: String) -> Bool {
        guard let logDate = Self.parseDate(dateString) else { return dateString.hasPrefix(dayKey) }
        return Self.utcDayKeyFormatter.string(from: logDate) == dayKey
    }

    private func handleBackAction() {
        if tabBar.config == .dailyHabits { tabBar.config = .default } else { dismiss() }
    }
}

// MARK: - Date Utilities

private extension DailyHabitsView {
    static let utcDayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    static func parseDate(_ string: String) -> Date? {
        isoFormatterWithFractional.date(from: string)
            ?? isoFormatter.date(from: string)
            ?? isoNoTimezoneDateTimeFormatter.date(from: string)
            ?? isoDateOnlyFormatter.date(from: string)
    }

    private static let isoFormatterWithFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    private static let isoNoTimezoneDateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return f
    }()

    private static let isoDateOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

// MARK: - Habit Row

private struct HabitRow: View {
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

    private enum HabitState { case pending, done, skipped, failed }
    private var state: HabitState {
        guard let completion else { return .pending }
        if completion.wasSkipped ?? false { return .skipped }
        return completion.completed ? .done : .failed
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

    // MARK: - Card

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            topRow
            Rectangle()
                .fill(Color.kalBorder)
                .frame(height: 1)
                .padding(.top, 10)
            footerRow
                .padding(.top, 10)
        }
        .padding(14)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(cardBorderColor, lineWidth: 1)
        )
        .overlay(alignment: .top) {
            ConfettiEmitterView(trigger: celebrationTrigger)
                .frame(height: 120)
                .offset(y: -10)
                .allowsHitTesting(false)
        }
        .animation(.easeInOut(duration: 0.15), value: state)
    }

    private var cardBackground: Color {
        switch state {
        case .done:              return Color.kalCardDone
        case .skipped, .failed:  return Color.kalCardFail
        case .pending:           return Color.kalSurface
        }
    }

    private var cardBorderColor: Color {
        switch state {
        case .done:              return Color.kalDone.opacity(0.18)
        case .skipped, .failed:  return Color.kalFail.opacity(0.16)
        case .pending:           return Color.kalBorder
        }
    }

    // MARK: - Top Row: type dot · name + meta · streak · toolbar

    private var topRow: some View {
        HStack(spacing: 10) {
            typeIndicator
            nameStack
            Spacer(minLength: 0)
            streakPill
            toolbarIcons
        }
    }

    private var typeIndicator: some View {
        Image(systemName: isPositive ? "arrow.up" : "arrow.down")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(isPositive ? Color.kalDone : Color.kalFail)
            .frame(width: 26, height: 26)
            .background(
                Circle().fill(isPositive ? Color.kalDoneBg : Color.kalFailBg)
            )
    }

    private var nameStack: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(habit.name)
                .font(.system(size: 14, weight: .semibold))
                .tracking(-0.28)
                .foregroundStyle(Color.kalPrimary)
                .lineLimit(1)

            HStack(spacing: 5) {
                Text((habit.frequency ?? "daily")
                    .replacingOccurrences(of: "_", with: " ")
                    .uppercased()
                )
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.54)
                .foregroundStyle(Color.kalTertiary)

                if let cat = habit.category, !cat.isEmpty {
                    Text("·").foregroundStyle(Color.kalTertiary)
                    Text(cat.uppercased())
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.54)
                        .foregroundStyle(Color.kalTertiary)
                }
            }
        }
    }

    @ViewBuilder
    private var streakPill: some View {
        if let s = habit.currentStreak, s > 0 {
            HStack(spacing: 3) {
                Image(systemName: "flame.fill").font(.system(size: 9))
                Text("\(s)").font(.system(size: 11, weight: .bold)).tracking(-0.11)
            }
            .foregroundStyle(Color.orange)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Color.orange.opacity(0.1), in: Capsule())
        }
    }

    private var toolbarIcons: some View {
        HStack(spacing: 12) {
            Button { onPomodoro(habit) } label: {
                Image(systemName: "timer")
                    .font(.system(size: 15, weight: .light))
                    .foregroundStyle(Color.kalTertiary)
            }
            .buttonStyle(.plain)

            Button { onNotification(habit) } label: {
                Image(systemName: "bell")
                    .font(.system(size: 15, weight: .light))
                    .foregroundStyle(Color.kalTertiary)
                    .overlay(alignment: .topTrailing) {
                        if notificationCount > 0 {
                            Circle().fill(Color.kalDone)
                                .frame(width: 5, height: 5)
                                .offset(x: 2, y: -1)
                        }
                    }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Footer Row: action buttons / state message

    @ViewBuilder
    private var footerRow: some View {
        if isPerformingAction {
            HStack {
                ProgressView().scaleEffect(0.8)
                Spacer()
            }
            .frame(height: 28)

        } else if state == .done {
            HStack(spacing: 5) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.kalDone)
                Text(isPositive ? "Checked in" : "Resisted")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(-0.12)
                    .foregroundStyle(Color.kalDone)
                Spacer()
            }

        } else if state == .skipped || state == .failed {
            HStack(spacing: 5) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.kalFail)
                Text(state == .skipped ? "Skipped" : "Failed")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(-0.12)
                    .foregroundStyle(Color.kalFail)
                Spacer()
            }

        } else {
            HStack(spacing: 6) {
                Button {
                    celebrationTrigger &+= 1
                    onAction(isPositive ? .checkIn(habit) : .resisted(habit))
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isPositive ? "checkmark" : "shield.checkered")
                            .font(.system(size: 11, weight: .semibold))
                        Text(isPositive ? "Check In" : "Resisted")
                            .font(.system(size: 12, weight: .semibold))
                            .tracking(-0.12)
                    }
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 13).padding(.vertical, 6)
                    .background(isPositive ? Color.kalPrimary : Color.kalDone, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isActionDisabled)

                Button {
                    onAction(isPositive ? .skipDay(habit) : .failedToResist(habit))
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isPositive ? "forward" : "xmark")
                            .font(.system(size: 11, weight: .semibold))
                        Text(isPositive ? "Skip" : "Failed")
                            .font(.system(size: 12, weight: .semibold))
                            .tracking(-0.12)
                    }
                    .foregroundStyle(Color.kalTertiary)
                    .padding(.horizontal, 13).padding(.vertical, 6)
                    .background(Color.kalSurface, in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.kalDivider, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(isActionDisabled)

                Spacer()
            }
        }
    }

    // MARK: - Swipe Layers

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
                    if openR      { dragOffset = swipeOpenWidth;  swipeDirection = .right }
                    else if openL { dragOffset = -swipeOpenWidth; swipeDirection = .left  }
                    else          { dragOffset = 0;               swipeDirection = .none  }
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
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.orange))
        .opacity(dragOffset > 0 ? min(dragOffset / 30.0, 1) : 0)
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
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.kalToday))
        .opacity(dragOffset < 0 ? min(abs(dragOffset) / 30.0, 1) : 0)
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
        } else {
            onSelect(habit)
        }
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

        var displayName: String { self == .build ? "Build" : "Break" }
        var icon: String { self == .build ? "arrow.up.circle.fill" : "arrow.down.circle.fill" }
        var color: Color { self == .build ? .green : .red }
    }

    enum Priority: String, CaseIterable {
        case high = "high"
        case medium = "medium"
        case low = "low"

        var displayName: String { rawValue.capitalized }
        var color: Color {
            switch self {
            case .high:   return .red
            case .medium: return .orange
            case .low:    return .blue
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
                        ForEach(HabitFilters.Priority.allCases, id: \.self) { p in
                            Text(p.displayName).tag(HabitFilters.Priority?.some(p))
                        }
                    }
                } header: {
                    Text("Filter By")
                } footer: {
                    if filters.hasActiveFilters {
                        Button("Clear All Filters") { filters = HabitFilters() }
                    }
                }

                Section {
                    DisclosureGroup(isExpanded: $isArchivedExpanded) {
                        if isLoadingArchived {
                            HStack { Spacer(); ProgressView(); Spacer() }
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
                                            if let p = habit.priority {
                                                Text("·")
                                                Text(p.capitalized)
                                            }
                                        }
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button("Restore") { unarchiveHabit(habit) }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                }
                            }
                        }
                    } label: {
                        Label("Archived Habits", systemImage: "archivebox.fill")
                    }
                    .onChange(of: isArchivedExpanded) { _, expanded in
                        if expanded && archivedHabits.isEmpty { loadArchivedHabits() }
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
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
        withAnimation { archivedHabits.removeAll { $0.id == habit.id } }
        onUnarchive(habit)
    }
}

// MARK: - Confetti Effect

private struct ConfettiEmitterView: UIViewRepresentable {
    let trigger: Int

    func makeUIView(context: Context) -> ConfettiHostView { ConfettiHostView() }

    func updateUIView(_ uiView: ConfettiHostView, context: Context) {
        guard context.coordinator.lastTrigger != trigger else { return }
        context.coordinator.lastTrigger = trigger
        uiView.emitOnce()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator { var lastTrigger: Int = 0 }

    final class ConfettiHostView: UIView {
        override init(frame: CGRect) { super.init(frame: frame); backgroundColor = .clear }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        func emitOnce() {
            guard bounds.width > 0 else {
                DispatchQueue.main.async { [weak self] in self?.emitOnce() }
                return
            }
            layer.sublayers?.filter { $0.name == "habit-confetti-layer" }.forEach { $0.removeFromSuperlayer() }
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { emitter.birthRate = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { emitter.removeFromSuperlayer() }
        }
    }

    private static func makeCells() -> [CAEmitterCell] {
        let colors: [UIColor] = [.systemGreen, .systemBlue, .systemPink, .systemYellow, .systemOrange, .systemPurple, .systemTeal]
        return colors.flatMap { color -> [CAEmitterCell] in
            let square = baseCell(color: color); square.scale = 0.07; square.scaleRange = 0.02
            let rect   = baseCell(color: color); rect.scale   = 0.08; rect.scaleRange   = 0.03
            rect.contents = UIImage(systemName: "rectangle.fill")?.cgImage
            return [square, rect]
        }
    }

    private static func baseCell(color: UIColor) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = UIImage(systemName: "circle.fill")?.cgImage
        cell.birthRate = 32; cell.lifetime = 2.5
        cell.velocity = 220;  cell.velocityRange = 60
        cell.emissionLongitude = .pi / 2; cell.emissionRange = .pi / 4
        cell.spin = 3.5; cell.spinRange = 2
        cell.yAcceleration = 320; cell.color = color.cgColor
        return cell
    }
}
