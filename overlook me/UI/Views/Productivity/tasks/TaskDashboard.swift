import SwiftUI
import UserNotifications

typealias ConcurrencyTask = _Concurrency.Task

// MARK: - Recurrence

enum RecurrenceFrequency: String, Codable, CaseIterable, Identifiable {
    case daily, weekdays, weekly, biweekly, monthly, yearly
    var id: String { rawValue }
    var label: String {
        switch self {
        case .daily: return "Daily"; case .weekdays: return "Weekdays"; case .weekly: return "Weekly"
        case .biweekly: return "Every 2 Weeks"; case .monthly: return "Monthly"; case .yearly: return "Yearly"
        }
    }
    var icon: String {
        switch self {
        case .daily: return "arrow.trianglehead.2.clockwise"; case .weekdays: return "calendar.day.timeline.leading"
        case .weekly: return "calendar.badge.clock"; case .biweekly: return "calendar.badge.plus"
        case .monthly: return "calendar"; case .yearly: return "sparkles"
        }
    }
}

struct TaskRecurrence: Codable { let frequency: RecurrenceFrequency; let endDate: Date? }

struct RecurrenceStore {
    private static let prefix = "task_recurrence_"
    static func get(for id: String) -> TaskRecurrence? {
        guard let d = UserDefaults.standard.data(forKey: prefix + id) else { return nil }
        return try? JSONDecoder().decode(TaskRecurrence.self, from: d)
    }
    static func set(_ r: TaskRecurrence?, for id: String) {
        if let r, let d = try? JSONEncoder().encode(r) { UserDefaults.standard.set(d, forKey: prefix + id) }
        else { UserDefaults.standard.removeObject(forKey: prefix + id) }
    }
    static func nextDueDate(from current: Date, frequency: RecurrenceFrequency) -> Date {
        let c = Calendar.current
        switch frequency {
        case .daily: return c.date(byAdding: .day, value: 1, to: current)!
        case .weekdays:
            var n = c.date(byAdding: .day, value: 1, to: current)!
            while c.isDateInWeekend(n) { n = c.date(byAdding: .day, value: 1, to: n)! }; return n
        case .weekly: return c.date(byAdding: .weekOfYear, value: 1, to: current)!
        case .biweekly: return c.date(byAdding: .weekOfYear, value: 2, to: current)!
        case .monthly: return c.date(byAdding: .month, value: 1, to: current)!
        case .yearly: return c.date(byAdding: .year, value: 1, to: current)!
        }
    }
}

// MARK: - Dashboard

struct TaskDashboard: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.injected) private var container
    @EnvironmentObject private var tabBar: TabBarStyleStore

    @State private var isPresentingAddTask = false
    @State private var selectedTask: Task?
    @State private var isPresentingViewTask = false
    @State private var completedTaskIds: Set<String> = []

    private var tasks: [Task] { container.appState.state.tasks.tasks }
    private var isLoading: Bool { container.appState.state.tasks.isLoading }
    private var error: Error? { container.appState.state.tasks.error }

    private var activeTasks: [Task] {
        tasks.filter { $0.status != .completed && $0.status != .cancelled && !completedTaskIds.contains($0.id) }
    }
    private var overdueTasks: [Task] {
        activeTasks.filter { $0.isOverdue && !$0.isDueToday }
            .sorted { ($0.dueDateTime ?? .distantPast) < ($1.dueDateTime ?? .distantPast) }
    }
    private var todayTasks: [Task] {
        activeTasks.filter { $0.isDueToday }
            .sorted { ($0.dueDateTime ?? .distantFuture) < ($1.dueDateTime ?? .distantFuture) }
    }
    private var tomorrowTasks: [Task] {
        activeTasks.filter { $0.isDueTomorrow }
            .sorted { ($0.dueDateTime ?? .distantFuture) < ($1.dueDateTime ?? .distantFuture) }
    }
    private var upcomingTasks: [Task] {
        activeTasks.filter {
            guard let d = $0.dueDateTime else { return false }
            return d > Date() && !$0.isDueToday && !$0.isDueTomorrow && !$0.isOverdue
        }
        .sorted { ($0.dueDateTime ?? .distantFuture) < ($1.dueDateTime ?? .distantFuture) }
    }
    private var anytimeTasks: [Task] {
        activeTasks.filter { $0.dueDateTime == nil }.sorted { $0.createdAt > $1.createdAt }
    }

    private var overdueCount: Int { activeTasks.filter { $0.isOverdue && !$0.isDueToday }.count }
    private var todayCount: Int { activeTasks.filter { $0.isDueToday || $0.isScheduledToday }.count }
    private var inProgressCount: Int { activeTasks.filter { $0.status == .inProgress }.count }
    private var pinnedCount: Int { activeTasks.filter { $0.isPinned }.count }
    @State private var pillsAppeared = false

    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemGroupedBackground).ignoresSafeArea()
            gradientLayer

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    analyticsCard
                    tasksContent
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 130)
                .padding(.bottom, 48)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            .refreshable { await loadTasks() }
        }
        .ignoresSafeArea(edges: .top)
        .navigationTitle("Tasks")
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
                Button { isPresentingAddTask = true } label: {
                    Image(systemName: "plus")
                        .font(.title3.weight(.semibold))
                }
            }
        }
        .sheet(isPresented: $isPresentingAddTask) {
            AddNewTask()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $isPresentingViewTask) {
            if let task = selectedTask {
                ViewTask(task: task)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
                    .presentationCornerRadius(28)
            }
        }
        .task { await loadTasks() }
    }

    // MARK: - Analytics Card

    private var analyticsCard: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
            analyticsPill(value: activeTasks.count, label: "Active", icon: "bolt.fill", color: .blue, delay: 0)
            analyticsPill(value: todayCount, label: "Today", icon: "sun.max.fill", color: .indigo, delay: 0.05)
            analyticsPill(value: overdueCount, label: "Overdue", icon: "exclamationmark.triangle.fill", color: .red, delay: 0.1)
            analyticsPill(value: inProgressCount, label: "Doing", icon: "arrow.triangle.2.circlepath", color: .orange, delay: 0.15)
            analyticsPill(value: pinnedCount, label: "Pinned", icon: "pin.fill", color: .yellow, delay: 0.2)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(TasksPalette.cardBackground(for: colorScheme))
                .shadow(color: TasksPalette.cardShadow(for: colorScheme), radius: 6, y: 3)
        )
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.1)) { pillsAppeared = true }
        }
    }

    private func analyticsPill(value: Int, label: String, icon: String, color: Color, delay: Double) -> some View {
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

    // MARK: - Tasks Content

    @ViewBuilder
    private var tasksContent: some View {
        if isLoading && tasks.isEmpty {
            loadingView
        } else if let error, tasks.isEmpty {
            errorView(error)
        } else if activeTasks.isEmpty && !isLoading {
            emptyView
        } else {
            VStack(spacing: 24) {
                taskGroup("Past Due", tasks: overdueTasks, tint: .red)
                taskGroup("Today", tasks: todayTasks, tint: .blue)
                taskGroup("Tomorrow", tasks: tomorrowTasks, tint: .indigo)
                taskGroup("Upcoming", tasks: upcomingTasks, tint: .purple)
                taskGroup("Anytime", tasks: anytimeTasks, tint: .gray)
            }
        }
    }

    @ViewBuilder
    private func taskGroup(_ title: String, tasks: [Task], tint: Color) -> some View {
        if !tasks.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundStyle(tint)
                        .textCase(.uppercase)
                    Text("\(tasks.count)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(tint, in: Capsule())
                }
                .padding(.leading, 4)
                .padding(.bottom, 2)

                ForEach(tasks) { task in
                    TaskCard(
                        task: task,
                        isCompleting: completedTaskIds.contains(task.id),
                        colorScheme: colorScheme,
                        onTap: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            selectedTask = task
                            isPresentingViewTask = true
                        },
                        onComplete: { completeTask(task) },
                        onDelete: { deleteTask(task) }
                    )
                }
            }
        }
    }

    // MARK: - State Views

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading your tasks…").font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 60)
    }

    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle").font(.system(size: 36)).foregroundColor(.orange)
            Text("Couldn't load tasks.").font(.headline)
            Text(error.localizedDescription).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Retry") { ConcurrencyTask { await loadTasks() } }.buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity).padding().background(cardBg)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checklist").font(.system(size: 40)).foregroundStyle(.secondary)
            Text("No tasks yet").font(.headline)
            Text("Create your first task to get started.").font(.subheadline).foregroundStyle(.secondary)
            Button { isPresentingAddTask = true } label: {
                Label("Create Task", systemImage: "plus").font(.subheadline.weight(.semibold))
            }.buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity).padding().background(cardBg)
    }

    private var cardBg: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(TasksPalette.cardBackground(for: colorScheme))
            .shadow(color: TasksPalette.cardShadow(for: colorScheme), radius: 8, y: 6)
    }

    // MARK: - Actions

    private func loadTasks() async {
        await container.interactors.tasksInteractor.loadTasks(
            status: nil, priority: nil, category: nil, project: nil,
            date: nil, isPinned: nil, isArchived: false, overdue: nil, includeCompleted: true
        )
    }

    private func completeTask(_ task: Task) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { completedTaskIds.insert(task.id) }
        ConcurrencyTask { @MainActor in
            try? await _Concurrency.Task.sleep(for: .milliseconds(500))
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            await container.interactors.tasksInteractor.updateTask(
                taskId: task.id, title: nil, description: nil, descriptionFormat: nil,
                status: .completed, priority: nil, scheduledDate: nil, scheduledTime: nil,
                dueDateTime: nil, estimatedDurationMinutes: nil, category: nil, project: nil,
                tags: nil, color: nil, progressPercentage: 100, location: nil,
                latitude: nil, longitude: nil, isProModeEnabled: nil, isFuture: nil
            )
            if let rec = RecurrenceStore.get(for: task.id) {
                let next = RecurrenceStore.nextDueDate(from: task.dueDateTime ?? Date(), frequency: rec.frequency)
                if rec.endDate == nil || next <= rec.endDate! {
                    await container.interactors.tasksInteractor.createTask(
                        title: task.title, description: task.description, descriptionFormat: "plain",
                        status: .pending, priority: task.priority, scheduledDate: next,
                        scheduledTime: task.scheduledTime, dueDateTime: next,
                        estimatedDurationMinutes: task.estimatedDurationMinutes,
                        category: task.category, project: task.project,
                        tags: task.tags.joined(separator: ","), color: task.color,
                        location: task.location, latitude: task.latitude, longitude: task.longitude,
                        isProModeEnabled: task.isProModeEnabled, isFuture: false
                    )
                    if let newId = container.appState.state.tasks.lastCreatedTaskId {
                        RecurrenceStore.set(rec, for: newId)
                    }
                }
            }
            completedTaskIds.remove(task.id)
        }
    }

    private func deleteTask(_ task: Task) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        ConcurrencyTask { @MainActor in
            await container.interactors.tasksInteractor.deleteTask(taskId: task.id)
            RecurrenceStore.set(nil, for: task.id)
        }
    }

    private func handleBackAction() {
        if tabBar.config == .productivity || tabBar.config == .tasks { tabBar.config = .default } else { dismiss() }
    }
}

// MARK: - Task Card (matches HabitRow pattern)

private struct TaskCard: View {
    let task: Task
    let isCompleting: Bool
    let colorScheme: ColorScheme
    let onTap: () -> Void
    let onComplete: () -> Void
    let onDelete: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var swipeOpen = false

    private let swipeThreshold: CGFloat = 50
    private let swipeWidth: CGFloat = 72

    private var recurrence: TaskRecurrence? { RecurrenceStore.get(for: task.id) }

    var body: some View {
        ZStack {
            deleteBackground
            cardContent
                .offset(x: dragOffset)
                .gesture(swipeGesture)
        }
        .clipped()
    }

    private var cardContent: some View {
        HStack(spacing: 14) {
            checkCircle
            labelsColumn
            Spacer(minLength: 0)
            priorityFlag
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(TasksPalette.cardBackground(for: colorScheme))
                .shadow(
                    color: isCompleting ? Color.green.opacity(0.15) : TasksPalette.cardShadow(for: colorScheme),
                    radius: isCompleting ? 8 : 5, y: 3
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isCompleting ? Color.green.opacity(0.3) : .clear, lineWidth: 1)
        )
        .opacity(isCompleting ? 0.5 : 1)
        .contentShape(Rectangle())
        .onTapGesture {
            if swipeOpen {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { dragOffset = 0; swipeOpen = false }
            } else { onTap() }
        }
        .contextMenu {
            Button { onComplete() } label: { Label("Complete", systemImage: "checkmark.circle") }
            Divider()
            Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
        }
    }

    private var checkCircle: some View {
        Button(action: onComplete) {
            ZStack {
                Circle()
                    .strokeBorder(isCompleting ? Color.green : priorityColor, lineWidth: 2)
                    .frame(width: 26, height: 26)
                if isCompleting {
                    Circle().fill(Color.green).frame(width: 26, height: 26).transition(.scale)
                    Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isCompleting)
        }
        .buttonStyle(.plain)
    }

    private var labelsColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(task.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isCompleting ? .secondary : .primary)
                .strikethrough(isCompleting)
                .lineLimit(2)

            HStack(spacing: 6) {
                if let due = task.dueDateTime {
                    Image(systemName: task.isOverdue ? "exclamationmark.circle.fill" : "calendar")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(task.isOverdue ? .red : .secondary)
                    Text(Self.relativeFormatter.localizedString(for: due, relativeTo: Date()))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(task.isOverdue ? Color.red : Color(.tertiaryLabel))
                }
                if recurrence != nil {
                    Image(systemName: "repeat").font(.system(size: 9, weight: .bold)).foregroundStyle(.blue)
                }
                if task.isPinned {
                    Image(systemName: "pin.fill").font(.system(size: 9)).foregroundStyle(.orange)
                }
                if let cat = task.category, !cat.isEmpty {
                    Text("·").foregroundStyle(.quaternary)
                    Text(cat).font(.caption2.weight(.medium)).foregroundStyle(.tertiary)
                }
            }

            if !task.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(task.tags.prefix(3), id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 9, weight: .semibold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1), in: Capsule())
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var priorityFlag: some View {
        switch task.priority {
        case .critical: Image(systemName: "flag.fill").font(.caption).foregroundStyle(.red).symbolEffect(.pulse, options: .repeating)
        case .high: Image(systemName: "flag.fill").font(.caption).foregroundStyle(.orange)
        case .medium: Image(systemName: "flag.fill").font(.caption).foregroundStyle(.blue)
        case .low: EmptyView()
        }
    }

    private var priorityColor: Color {
        switch task.priority {
        case .critical: return .red; case .high: return .orange; case .medium: return .blue; case .low: return Color(.tertiaryLabel)
        }
    }

    // MARK: - Swipe

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onChanged { v in
                let base: CGFloat = swipeOpen ? -swipeWidth : 0
                dragOffset = max(-swipeWidth - 30, min(base + v.translation.width, 30))
            }
            .onEnded { v in
                let vel = v.predictedEndTranslation.width - v.translation.width
                let open = dragOffset < -swipeThreshold / 2 || vel < -100
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    if open { dragOffset = -swipeWidth; swipeOpen = true }
                    else { dragOffset = 0; swipeOpen = false }
                }
            }
    }

    private var deleteBackground: some View {
        HStack {
            Spacer()
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { dragOffset = 0; swipeOpen = false }
                onDelete()
            } label: {
                Image(systemName: "trash.fill")
                    .font(.body.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(width: swipeWidth)
                    .frame(maxHeight: .infinity)
            }
            .buttonStyle(.plain)
        }
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.red))
        .opacity(dragOffset < 0 ? min(abs(dragOffset) / CGFloat(30), 1) : 0)
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter(); f.unitsStyle = .abbreviated; return f
    }()
}

// MARK: - Gradient & Palette

private extension TaskDashboard {
    var gradientLayer: some View {
        VStack(spacing: 0) {
            TasksPalette.headerGradient(for: colorScheme)
                .frame(height: 280)
                .overlay(TasksPalette.highlightGradient(for: colorScheme))
                .overlay(TasksPalette.glossOverlay(for: colorScheme))
                .overlay(alignment: .bottom) {
                    TasksPalette.fadeOverlay(for: colorScheme).frame(height: 98)
                }
                .frame(maxWidth: .infinity)
            Spacer()
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

private enum TasksPalette {
    private static let blush = Color(uiColor: .systemPurple).opacity(0.85)
    private static let lilac = Color(uiColor: .systemIndigo).opacity(0.85)
    private static let periwinkle = Color(uiColor: .systemBlue).opacity(0.75)
    private static let teal = Color(uiColor: .systemTeal).opacity(0.6)

    static func headerGradient(for cs: ColorScheme) -> LinearGradient {
        LinearGradient(colors: stops(for: cs), startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static func highlightGradient(for cs: ColorScheme) -> LinearGradient {
        let lo = cs == .dark ? 0.18 : 0.45; let to = cs == .dark ? 0.05 : 0.15
        return LinearGradient(colors: [.white.opacity(lo), .white.opacity(to), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static func glossOverlay(for cs: ColorScheme) -> some View {
        let oo = cs == .dark ? 0.28 : 0.6; let go = cs == .dark ? 0.2 : 0.45
        return ZStack {
            RadialGradient(colors: [.white.opacity(go), .white.opacity(0.08), .clear], center: .topLeading, startRadius: 24, endRadius: 420)
            LinearGradient(colors: [.white.opacity(cs == .dark ? 0.2 : 0.35), .white.opacity(cs == .dark ? 0.04 : 0.05), .clear], startPoint: .top, endPoint: .bottom)
        }.blendMode(cs == .dark ? .plusLighter : .screen).opacity(oo)
    }
    static func fadeOverlay(for cs: ColorScheme) -> LinearGradient {
        LinearGradient(colors: [.clear, Color(.systemGroupedBackground)], startPoint: .top, endPoint: .bottom)
    }
    static func cardBackground(for cs: ColorScheme) -> Color {
        cs == .dark ? Color(uiColor: .secondarySystemBackground) : Color(.systemBackground)
    }
    static func cardShadow(for cs: ColorScheme) -> Color {
        .black.opacity(cs == .dark ? 0.45 : 0.08)
    }
    private static func stops(for cs: ColorScheme) -> [Color] {
        cs == .dark ? [blush.opacity(0.65), lilac.opacity(0.5), periwinkle.opacity(0.45), teal.opacity(0.4)] : [blush, lilac, periwinkle, teal]
    }
}
