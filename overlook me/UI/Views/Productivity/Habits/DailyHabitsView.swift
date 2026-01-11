import SwiftUI

struct DailyHabitsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.injected) private var container: DIContainer
    @EnvironmentObject private var tabBar: TabBarStyleStore
    @State private var isPresentingAddHabit = false
    @State private var selectedDate = Date()
    @State private var lastLoadedSignature: String?
    @State private var displayedHabits: [DailyHabitDTO] = []
    @State private var actionErrorMessage: String?
    @State private var pendingHabitId: String?
    @State private var showFullInsight = false
    
    private var habitsState: AppState.HabitsState { container.appState.state.habits }
    private var habitsInteractor: HabitsInteractor { container.interactors.habitsInteractor }
    private var backendUserId: String? {
        guard let user = container.appState.state.auth.user else { return nil }
        return user.oauthId.isEmpty ? user.id : user.oauthId
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
            Task { await loadHabitsIfNeeded(force: true) }
        }
        .onChange(of: selectedDate) { _ in
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
        if habitsState.isLoading {
            VStack(spacing: 16) {
                ProgressView()
                Text("Loading your habits…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        } else if let error = habitsState.error {
            habitsErrorView(error)
        } else if displayedHabits.isEmpty {
            habitsEmptyView
        } else {
            VStack(spacing: 16) {
                ForEach(displayedHabits) { habit in
                    HabitCardView(
                        habit: habit,
                        isPerformingAction: pendingHabitId == habit.id,
                        onAction: handleHabitAction
                    )
                }
            }
        }
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
        guard let userId = backendUserId else { return }
        let dateString = Self.dayFormatter.string(from: selectedDate)
        let signature = "\(userId)|\(dateString)"
        
        guard force || lastLoadedSignature != signature || habitsState.habits.isEmpty else { return }
        lastLoadedSignature = signature
        await habitsInteractor.loadHabits(for: selectedDate)
        await MainActor.run {
            displayedHabits = container.appState.state.habits.habits
        }
    }

    private func handleHabitAction(_ action: HabitAction) {
        guard pendingHabitId == nil else { return }
        guard let userId = backendUserId else {
            actionErrorMessage = "Please sign in again to update this habit."
            return
        }
        
        let oauthId = container.appState.state.auth.user?.oauthId
        let targetDate = selectedDate
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

    private func handleBackAction() {
        if tabBar.config == .dailyHabits {
            tabBar.config = .default
        } else {
            dismiss()
        }
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
    let isPerformingAction: Bool
    let onAction: (HabitAction) -> Void
    
    private var priorityLabel: String? { habit.priority?.capitalized }
    private var frequencyLabel: String {
        (habit.frequency ?? "daily").replacingOccurrences(of: "_", with: " ").capitalized
    }
    private var isPositiveHabit: Bool { habit.isPositive ?? true }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            metaRow
            actionRow
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(DailyHabitsPalette.cardBackground(for: colorScheme))
                .shadow(color: DailyHabitsPalette.cardShadow(for: colorScheme), radius: 12, y: 8)
        )
    }
    
    private var headerRow: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(habit.name)
                        .font(.headline)
                    TagView(title: isPositiveHabit ? "Good Habit" : "Reduce Habit",
                            tint: isPositiveHabit ? .green.opacity(0.15) : .red.opacity(0.15),
                            textColor: isPositiveHabit ? .green : .red)
                }
                if let description = habit.description, !description.isEmpty {
                    Text(description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
            Spacer(minLength: 8)
            if let priorityLabel {
                TagView(title: priorityLabel,
                        tint: Color.accentColor.opacity(0.15),
                        textColor: Color.accentColor)
            }
        }
    }
    
    private var metaRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Label(frequencyLabel, systemImage: "repeat")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let streak = habit.currentStreak, streak > 0 {
                    Label("\(streak) day streak", systemImage: "flame.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                if let completions = habit.totalCompletions, completions > 0 {
                    Label("\(completions) wins", systemImage: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            
            WeekRhythmIndicator(targetDays: nil, isPositive: isPositiveHabit)
        }
    }
    
    @ViewBuilder
    private var actionRow: some View {
        if isPositiveHabit {
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
                    tint: Color(.systemGray5),
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
                    tint: .red.opacity(0.15),
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
        Button {
            onAction(action)
        } label: {
            Label(title, systemImage: systemIcon)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(style.backgroundColor(colorScheme))
                .foregroundStyle(style.foregroundColor(colorScheme))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isPerformingAction)
        .opacity(isPerformingAction ? 0.6 : 1)
    }
    
    private func secondaryActionButton(
        title: String,
        systemIcon: String,
        tint: Color,
        action: HabitAction
    ) -> some View {
        Button {
            onAction(action)
        } label: {
            Label(title, systemImage: systemIcon)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(tint.opacity(colorScheme == .dark ? 0.4 : 1))
                .foregroundStyle(colorScheme == .dark ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isPerformingAction)
        .opacity(isPerformingAction ? 0.6 : 1)
    }
    
    private enum PrimaryActionStyle {
        case checkIn
        case resisted
        
        func backgroundColor(_ scheme: ColorScheme) -> Color {
            switch self {
            case .checkIn:
                return Color.blue.opacity(scheme == .dark ? 0.7 : 1)
            case .resisted:
                return Color.green.opacity(scheme == .dark ? 0.6 : 0.85)
            }
        }
        
        func foregroundColor(_ scheme: ColorScheme) -> Color {
            switch self {
            case .checkIn:
                return Color.white
            case .resisted:
                return scheme == .dark ? Color.white : Color.black
            }
        }
    }
}

private struct TagView: View {
    let title: String
    let tint: Color
    let textColor: Color
    
    var body: some View {
        Text(title.uppercased())
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint)
            .foregroundStyle(textColor)
            .clipShape(Capsule())
    }
}

private struct WeekRhythmIndicator: View {
    let targetDays: [String]?
    let isPositive: Bool
    private let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    
    var body: some View {
        HStack(spacing: 6) {
            Text("Week rhythm")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(days, id: \.self) { day in
                Circle()
                    .fill(color(for: day))
                    .frame(width: 8, height: 8)
            }
        }
    }
    
    private func color(for day: String) -> Color {
        guard let targetDays, !targetDays.isEmpty else {
            return (isPositive ? Color.green : Color.red).opacity(0.25)
        }
        return targetDays.contains(day.lowercased()) ? (isPositive ? .green : .red) : Color.gray.opacity(0.25)
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
        
        return LogHabitCompletionRequestDTO(
            habitId: habit.id,
            date: dateString,
            completed: payload.0,
            value: nil,
            notes: nil,
            wasSkipped: payload.1,
            completedAt: completedAt,
            metrics: [],
            reason: nil,
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

