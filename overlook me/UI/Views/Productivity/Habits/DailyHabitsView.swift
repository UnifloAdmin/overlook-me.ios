import SwiftUI
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
        GeometryReader { proxy in
            content(topInset: proxy.safeAreaInsets.top, size: proxy.size)
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
    
    private func content(topInset: CGFloat, size: CGSize) -> some View {
        let headerHeight = headerHeight(for: size)
        let overlayHeight = headerHeight * 0.35
        return ZStack(alignment: .top) {
            Color(.systemGroupedBackground).ignoresSafeArea()
            gradientLayer(headerHeight: headerHeight, overlayHeight: overlayHeight)
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    headerPlaceholder
                    habitsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, contentTopPadding(topInset: topInset, headerHeight: headerHeight))
                .padding(.bottom, 48)
            }
            .refreshable { await loadHabitsIfNeeded(force: true) }
        }
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
            HabitDetailSheetView(
                habit: habit,
                completion: completionLog(for: habit),
                isPerformingAction: pendingHabitId == habit.id,
                onAction: handleHabitAction
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }
    
    private func headerHeight(for size: CGSize) -> CGFloat {
        max(size.height * 0.4, 220)
    }
    
    private func contentTopPadding(topInset: CGFloat, headerHeight: CGFloat) -> CGFloat {
        let desiredOverlap = headerHeight * 0.32
        let rawPadding = topInset - desiredOverlap
        let minimumPadding = -headerHeight * 0.25
        let maximumPadding: CGFloat = 40
        return min(max(rawPadding, minimumPadding), maximumPadding)
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
                        onSelect: { selectedHabitForDetail = $0 }
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
    func gradientLayer(headerHeight: CGFloat, overlayHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            DailyHabitsPalette.headerGradient(for: colorScheme)
                .frame(height: headerHeight)
                .overlay(DailyHabitsPalette.highlightGradient(for: colorScheme))
                .overlay(DailyHabitsPalette.glossOverlay(for: colorScheme))
                .overlay(alignment: .bottom) {
                    DailyHabitsPalette.fadeOverlay(for: colorScheme)
                        .frame(height: overlayHeight)
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
    let onSelect: (DailyHabitDTO) -> Void
    let extraContent: AnyView?
    
    init(
        habit: DailyHabitDTO,
        completion: HabitCompletionLogDTO?,
        isPerformingAction: Bool,
        onAction: @escaping (HabitAction) -> Void,
        onSelect: @escaping (DailyHabitDTO) -> Void,
        extraContent: AnyView? = nil
    ) {
        self.habit = habit
        self.completion = completion
        self.isPerformingAction = isPerformingAction
        self.onAction = onAction
        self.onSelect = onSelect
        self.extraContent = extraContent
    }
    
    private var priorityLabel: String? { habit.priority?.capitalized }
    private var frequencyLabel: String {
        (habit.frequency ?? "daily").replacingOccurrences(of: "_", with: " ").capitalized
    }
    private var isPositiveHabit: Bool { habit.isPositive ?? true }
    private var isActionDisabled: Bool { isPerformingAction || completion != nil }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            metaRow
            actionRow
            
            if let extraContent {
                Divider()
                    .background(Color.white.opacity(colorScheme == .dark ? 0.05 : 0.08))
                extraContent
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(DailyHabitsPalette.cardBackground(for: colorScheme))
                .shadow(color: DailyHabitsPalette.cardShadow(for: colorScheme), radius: 12, y: 8)
        )
        .onTapGesture { onSelect(habit) }
    }
    
    private var headerRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(habit.name)
                .font(.title3.weight(.bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.tail)
            if let description = habit.description, !description.isEmpty {
                Text(description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
    }
    
    private var metaRow: some View {
        HStack(spacing: 8) {
            habitTypeBadge
            priorityChip
            cadenceChip
            Spacer(minLength: 0)
        }
    }
    
    @ViewBuilder
    private var actionRow: some View {
        if let completion {
            completionStatusButton(for: completion)
        } else if isPositiveHabit {
            VStack(spacing: 12) {
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
            onAction(action)
        } label: {
            Label(title, systemImage: systemIcon)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(
                    Capsule().fill(palette.fillColor)
                )
                .foregroundStyle(Color.white)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isActionDisabled)
        .opacity(isActionDisabled ? 0.6 : 1)
    }
    
    private func secondaryActionButton(
        title: String,
        systemIcon: String,
        tint: Color,
        action: HabitAction
    ) -> some View {
        let fill = tint.opacity(colorScheme == .dark ? 0.35 : 0.15)
        let foreground = colorScheme == .dark ? .white : tint
        return Button {
            onAction(action)
        } label: {
            Label(title, systemImage: systemIcon)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(
                    Capsule().fill(fill)
                )
                .foregroundStyle(foreground)
                .clipShape(Capsule())
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

    private var habitTypeBadge: some View {
        let fill = (isPositiveHabit ? Color.green : Color.red)
            .opacity(colorScheme == .dark ? 0.7 : 0.92)
        return Label(isPositiveHabit ? "Build Habit" : "Break Habit",
                     systemImage: isPositiveHabit ? "hammer.fill" : "scissors")
        .font(.caption2.weight(.bold))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .foregroundStyle(Color.white)
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        .background(
            Capsule()
                .fill(fill)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.15 : 0.2), lineWidth: 0.5)
                )
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.15), radius: 6, y: 3)
    }
    
    private var priorityChip: some View {
        let hasPriority = priorityLabel != nil
        let label = hasPriority ? priorityLabel! : "Not set"
        let (fill, textColor) = priorityStyle(for: label)
        return Text(label.uppercased())
            .font(.caption2.weight(.heavy))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(fill)
            )
            .foregroundStyle(textColor)
            .overlay(
                Capsule()
                    .stroke(textColor.opacity(0.25), lineWidth: 0.5)
            )
    }
    
    private var cadenceChip: some View {
        Label {
            Text("Cadence \(frequencyLabel)")
        } icon: {
            Image(systemName: "metronome.fill")
        }
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.blue.opacity(colorScheme == .dark ? 0.45 : 0.2))
        )
        .foregroundStyle(colorScheme == .dark ? Color.white : Color.blue)
    }
    
    private func priorityStyle(for label: String) -> (fill: Color, text: Color) {
        switch label.lowercased() {
        case "high":
            return (
                Color.red.opacity(colorScheme == .dark ? 0.4 : 0.2),
                Color.red
            )
        case "medium":
            return (
                Color.yellow.opacity(colorScheme == .dark ? 0.4 : 0.25),
                Color.yellow.darker(for: colorScheme)
            )
        case "low":
            return (
                Color.blue.opacity(colorScheme == .dark ? 0.35 : 0.2),
                Color.blue
            )
        default:
            return (
                Color.gray.opacity(0.15),
                Color.secondary
            )
        }
    }
}

private struct HabitDetailSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let habit: DailyHabitDTO
    let completion: HabitCompletionLogDTO?
    let isPerformingAction: Bool
    let onAction: (HabitAction) -> Void
    
    private var frequencyLabel: String {
        (habit.frequency ?? "daily").replacingOccurrences(of: "_", with: " ").capitalized
    }
    
    private var detailMetrics: [(title: String, value: String)] {
        [
            ("Frequency", frequencyLabel),
            ("Priority", habit.priority?.capitalized ?? "Not set")
        ]
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    HabitCardView(
                        habit: habit,
                        completion: completion,
                        isPerformingAction: isPerformingAction,
                        onAction: onAction,
                        onSelect: { _ in }
                    )
                    trackerSection(for: habit)
                    metricsSection
                }
                .padding(.top, 32)
                .padding(.bottom, 48)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Habit Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.body.weight(.semibold))
                }
            }
        }
    }
    
    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Snapshot")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(detailMetrics, id: \.title) { metric in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(metric.title.uppercased())
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                        Text(metric.value)
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(uiColor: .secondarySystemBackground))
                    )
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private func trackerSection(for habit: DailyHabitDTO) -> some View {
        if let logs = habit.completionLogs, !logs.isEmpty {
            HabitCycleTracker(logs: logs)
                .padding(.vertical, 18)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(DailyHabitsPalette.cardBackground(for: colorScheme))
                        .shadow(color: DailyHabitsPalette.cardShadow(for: colorScheme), radius: 12, y: 8)
                )
                .padding(.horizontal, 20)
        }
    }
}

private struct WeekRhythmIndicator: View {
    let selectedDays: Set<HabitWeekday>
    let isPositive: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            Text("Week rhythm")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(HabitWeekday.displayOrder) { day in
                Circle()
                    .fill(color(for: day))
                    .frame(width: 8, height: 8)
            }
        }
    }
    
    private func color(for day: HabitWeekday) -> Color {
        guard !selectedDays.isEmpty else {
            return (isPositive ? Color.green : Color.red).opacity(0.25)
        }
        return selectedDays.contains(day) ? (isPositive ? .green : .red) : Color.gray.opacity(0.25)
    }
}

private extension HabitCompletionLogDTO {
    func matches(dayKey: String) -> Bool {
        date.hasPrefix(dayKey)
    }
}

private enum HabitAction {
    case checkIn(DailyHabitDTO)
    case skipDay(DailyHabitDTO)
    case resisted(DailyHabitDTO)
    case failedToResist(DailyHabitDTO)
    
    var habit: DailyHabitDTO {
        switch self {
        case .checkIn(let habit),
             .skipDay(let habit),
             .resisted(let habit),
             .failedToResist(let habit):
            return habit
        }
    }
    
    func makeRequest(selectedDate: Date, isoFormatter: ISO8601DateFormatter) -> LogHabitCompletionRequestDTO {
        let dayStart = Calendar.current.startOfDay(for: selectedDate)
        let dateString = isoFormatter.string(from: dayStart)
        let completedAt = isoFormatter.string(from: Date())
        
        let payload: (Bool, Bool) = {
            switch self {
            case .checkIn:
                return (true, false)
            case .skipDay:
                return (false, true)
            case .resisted:
                return (true, false)
            case .failedToResist:
                return (false, false)
            }
        }()
        
        let reason: CompletionReasonDTO? = {
            switch self {
            case .skipDay:
                return CompletionReasonDTO(
                    reasonType: "skip",
                    reasonText: "Skipped from iOS",
                    triggerCategory: "manual",
                    sentiment: nil
                )
            case .failedToResist:
                return CompletionReasonDTO(
                    reasonType: "failure",
                    reasonText: "Marked as failed from iOS",
                    triggerCategory: "manual",
                    sentiment: nil
                )
            default:
                return nil
            }
        }()
        
        return LogHabitCompletionRequestDTO(
            habitId: habit.id,
            date: dateString,
            completed: payload.0,
            value: nil,
            notes: nil,
            wasSkipped: payload.1,
            completedAt: completedAt,
            metrics: [],
            reason: reason,
            generalNotes: nil
        )
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

