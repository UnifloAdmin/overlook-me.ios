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
    @State private var displayedHabits: [DailyHabitDTO] = []
    @State private var selectedHabitForDetail: DailyHabitDTO?
    @State private var selectedHabitForNotification: DailyHabitDTO?
    @State private var selectedHabitForPomodoro: DailyHabitDTO?
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
                VStack(alignment: .leading, spacing: 24) {
                    headerPlaceholder
                    habitsSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 125)  // Manual padding: status bar (~47) + nav bar (~44) + spacing (24)
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
        VStack(alignment: .leading, spacing: 12) {
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
        
        guard force || lastLoadedSignature != signature || habitsState.habits.isEmpty else {
            await MainActor.run {
                displayedHabits = container.appState.state.habits.habits
                isBootstrappingHabits = false
            }
            return
        }
        lastLoadedSignature = signature
        await habitsInteractor.loadHabits(for: selectedDate)
        await MainActor.run {
            displayedHabits = container.appState.state.habits.habits
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
            guard override.matches(dayKey: dayKey) else { return false }
            guard let logs = habits.first(where: { $0.id == habitId })?.completionLogs else {
                return true
            }
            return !logs.contains(where: { $0.matches(dayKey: dayKey) })
        }
    }

    private func handleHabitAction(_ action: HabitAction) {
        guard pendingHabitId == nil else { return }
        guard !hasLoggedAction(for: action.habit) else {
            let dateLabel = Self.displayDateFormatter.string(from: selectedDate)
            actionErrorMessage = "You've already logged this habit for \(dateLabel)."
            return
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
                    localCompletions[updatedHabit.id] = HabitCompletionLogDTO(
                        date: dayKey,
                        completed: request.completed,
                        value: request.value,
                        notes: request.notes,
                        completedAt: isoDateFormatter.string(from: Date()),
                        wasSkipped: request.wasSkipped ?? false
                    )
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

    private func completionLog(for habit: DailyHabitDTO) -> HabitCompletionLogDTO? {
        let dayKey = Self.dayFormatter.string(from: selectedDate)
        if let override = localCompletions[habit.id], override.matches(dayKey: dayKey) {
            return override
        }
        guard let logs = habit.completionLogs else { return nil }
        return logs.first(where: { $0.matches(dayKey: dayKey) })
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
    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(secondsFromGMT: 0) 
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
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
                .opacity(0.5)
            
            metaRow
            
            Divider()
                .opacity(0.5)
            
            actionRow
            
            if let extraContent {
                Divider()
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
                .font(.title3.weight(.bold))
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
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(palette.fillColor)
                .foregroundStyle(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
        let fill = Color(uiColor: .secondarySystemFill)
        let foreground = Color.secondary
        return Button {
            onAction(action)
        } label: {
            Label(title, systemImage: systemIcon)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(fill)
                .foregroundStyle(foreground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                return ButtonPalette(
                    fillColor: Color.blue.opacity(scheme == .dark ? 0.85 : 0.95)
                )
            case .resisted:
                return ButtonPalette(
                    fillColor: Color.green.opacity(scheme == .dark ? 0.85 : 0.9)
                )
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
    func matches(dayKey: String) -> Bool {
        date.hasPrefix(dayKey)
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

