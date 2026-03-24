import SwiftUI
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

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

// MARK: - Task Filters

enum TaskFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case overdue = "Past Due"
    case today = "Today"
    case tomorrow = "Tomorrow"
    
    var id: String { rawValue }
}

// MARK: - Dashboard

struct TaskDashboard: View {
    @Environment(\.injected) private var container
    @Namespace private var animation

    @State private var isPresentingAddTask = false
    @State private var selectedTask: Task?
    @State private var isPresentingViewTask = false
    @State private var completedTaskIds: Set<String> = []
    @State private var isBootstrappingTasks = true

    private var tasks: [Task] { container.appState.state.tasks.tasks }
    private var isLoading: Bool { container.appState.state.tasks.isLoading }
    private var error: Error? { container.appState.state.tasks.error }

    private var activeTasks: [Task] {
        tasks.filter {
            $0.status != .completed &&
            $0.status != .cancelled &&
            !completedTaskIds.contains($0.id)
        }
    }
    private var scheduledTasks: [Task] {
        activeTasks.filter { $0.dueDateTime != nil }
    }

    private var overdueCount: Int { scheduledTasks.filter { $0.isOverdue && !$0.isDueToday }.count }
    private var todayCount: Int { scheduledTasks.filter { $0.isDueToday }.count }
    private var inProgressCount: Int { activeTasks.filter { $0.status == .inProgress }.count }
    
    @State private var pillsAppeared = false
    @State private var selectedFilter: TaskFilter = .all
    
    private var displayedTasks: [Task] {
        switch selectedFilter {
        case .all: return activeTasks
        case .overdue: return scheduledTasks.filter { $0.isOverdue && !$0.isDueToday }
        case .today: return scheduledTasks.filter { $0.isDueToday }
        case .tomorrow: return scheduledTasks.filter { $0.isDueTomorrow }
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            TasksKalshiStyle.pageBackground.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    analyticsCard
                        .padding(.horizontal, 16)
                    
                    filterPillsSection
                    
                    tasksContent
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 16)
                .padding(.bottom, 48)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            .refreshable { await loadTasks() }
        }
        .navigationTitle("Tasks")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { isPresentingAddTask = true } label: {
                    Image(systemName: "plus")
                        .font(.title3.weight(.semibold))
                }
            }
        }
        .sheet(isPresented: $isPresentingAddTask, onDismiss: {
            isBootstrappingTasks = true
            ConcurrencyTask {
                await loadTasks()
                await MainActor.run { isBootstrappingTasks = false }
            }
        }) {
            AddNewTask()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
        }
        .sheet(isPresented: $isPresentingViewTask) {
            if let task = selectedTask {
                ViewTask(task: task)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
                    .presentationCornerRadius(24)
            }
        }
        .task {
            await loadTasks()
            await MainActor.run { isBootstrappingTasks = false }
        }
    }

    // MARK: - Analytics Card

    private var analyticsCard: some View {
        HStack(spacing: 0) {
            analyticsPill(value: todayCount, label: "Today", icon: "sun.max.fill", color: TasksKalshiStyle.today)
            metricDivider
            analyticsPill(value: overdueCount, label: "Past Due", icon: "exclamationmark.triangle.fill", color: TasksKalshiStyle.danger)
            metricDivider
            analyticsPill(value: inProgressCount, label: "In Progress", icon: "arrow.triangle.2.circlepath", color: TasksKalshiStyle.warning)
        }
        .padding(12)
        .tasksDataCard()
        .onAppear { pillsAppeared = true }
    }

    private func analyticsPill(value: Int, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(color)
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .kerning(0.5)
                    .foregroundStyle(TasksKalshiStyle.tertiaryText)
            }
            Text("\(value)")
                .font(.system(size: 20, weight: .bold))
                .tracking(-0.8)
                .foregroundStyle(TasksKalshiStyle.primaryText)
                .contentTransition(.numericText(value: Double(value)))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .scaleEffect(pillsAppeared ? 1 : 0.7)
        .opacity(pillsAppeared ? 1 : 0)
        .animation(.easeInOut(duration: 0.15), value: pillsAppeared)
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(TasksKalshiStyle.divider)
            .frame(width: 1, height: 30)
    }

    // MARK: - Filter Pills
    
    private var filterPillsSection: some View {
        HStack(spacing: 0) {
            ForEach(Array(TaskFilter.allCases.enumerated()), id: \.element.id) { index, filter in
                filterPill(filter: filter)
                
                if index < TaskFilter.allCases.count - 1 {
                    Rectangle()
                        .fill(TasksKalshiStyle.cardBorder)
                        .frame(width: 1, height: 18)
                        .zIndex(1) // Keep the divider visible above the background
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background(TasksKalshiStyle.surfaceMuted)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(TasksKalshiStyle.cardBorder, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    private func filterPill(filter: TaskFilter) -> some View {
        let isSelected = selectedFilter == filter
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75, blendDuration: 0)) {
                selectedFilter = filter
            }
        } label: {
            ZStack {
                if isSelected {
                    Capsule()
                        .fill(TasksKalshiStyle.primaryText)
                        .matchedGeometryEffect(id: "activeFilterPill", in: animation)
                }
                
                HStack(spacing: 4) {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(TasksKalshiStyle.pageBackground) // inverse color for check
                            .transition(.scale.combined(with: .opacity))
                    }
                    Text(filter.rawValue)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isSelected ? TasksKalshiStyle.pageBackground : TasksKalshiStyle.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 10)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle()) // Ensure entire area is clickable even if background is clear
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tasks Content

    @ViewBuilder
    private var tasksContent: some View {
        if isBootstrappingTasks && tasks.isEmpty {
            loadingView
                .padding(.horizontal, 16)
        } else if (isLoading && tasks.isEmpty) {
            loadingView
                .padding(.horizontal, 16)
        } else if let error, tasks.isEmpty {
            errorView(error)
                .padding(.horizontal, 16)
        } else if displayedTasks.isEmpty && !isLoading {
            emptyView
                .padding(.horizontal, 16)
        } else {
            VStack(spacing: 8) {
                ForEach(displayedTasks.sorted { ($0.dueDateTime ?? .distantFuture) < ($1.dueDateTime ?? .distantFuture) }) { task in
                    TaskCard(
                        task: task,
                        isCompleting: completedTaskIds.contains(task.id),
                        onTap: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            selectedTask = task
                            isPresentingViewTask = true
                        },
                        onComplete: { completeTask(task) },
                        onDelete: { deleteTask(task) },
                        onStatusChange: { newStatus in changeStatus(task, to: newStatus) }
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - State Views

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().tint(TasksKalshiStyle.primaryText)
            Text("Loading your tasks…").font(.callout).foregroundStyle(TasksKalshiStyle.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .tasksDataCard(cornerRadius: 20)
    }

    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle").font(.system(size: 36)).foregroundColor(TasksKalshiStyle.danger)
            Text("Couldn't load tasks.").font(.headline).foregroundStyle(TasksKalshiStyle.primaryText)
            Text(error.localizedDescription).font(.subheadline).foregroundStyle(TasksKalshiStyle.secondaryText).multilineTextAlignment(.center)
            Button("Retry") { ConcurrencyTask { await loadTasks() } }
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 13)
                .padding(.vertical, 6)
                .background(TasksKalshiStyle.primaryButtonBg, in: Capsule())
                .foregroundStyle(TasksKalshiStyle.primaryButtonFg)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .tasksDataCard(cornerRadius: 20)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            if UIImage(named: "undraw_creative-designer_sctu") != nil {
                Image("undraw_creative-designer_sctu")
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 150)
            } else {
                Image(systemName: "checklist")
                    .font(.system(size: 40))
                    .foregroundStyle(TasksKalshiStyle.tertiaryText)
            }
            Text("No tasks yet").font(.headline).foregroundStyle(TasksKalshiStyle.primaryText)
            Text("Create your first task to get started.").font(.subheadline).foregroundStyle(TasksKalshiStyle.secondaryText)
            Button { isPresentingAddTask = true } label: {
                Label("Create Task", systemImage: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 13)
                    .padding(.vertical, 6)
                    .background(TasksKalshiStyle.primaryButtonBg, in: Capsule())
                    .foregroundStyle(TasksKalshiStyle.primaryButtonFg)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .tasksDataCard(cornerRadius: 20)
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
        withAnimation(.easeInOut(duration: 0.15)) { completedTaskIds.insert(task.id) }
        ConcurrencyTask { @MainActor in
            try? await _Concurrency.Task.sleep(for: .milliseconds(500))
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            await container.interactors.tasksInteractor.updateTask(
                taskId: task.id, title: nil, description: nil, descriptionFormat: nil,
                status: .completed, priority: nil, scheduledDate: nil, scheduledTime: nil,
                dueDateTime: nil, estimatedDurationMinutes: nil, category: nil, project: nil,
                tags: nil, color: nil, progressPercentage: 100, location: nil,
                latitude: nil, longitude: nil, isProModeEnabled: nil, isFuture: nil, subtasks: nil
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
                        isProModeEnabled: task.isProModeEnabled, isFuture: false, subtasks: nil
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

    private func changeStatus(_ task: Task, to status: TaskStatus) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if status == .completed {
            completeTask(task); return
        }
        ConcurrencyTask { @MainActor in
            await container.interactors.tasksInteractor.updateTask(
                taskId: task.id, title: nil, description: nil, descriptionFormat: nil,
                status: status, priority: nil, scheduledDate: nil, scheduledTime: nil,
                dueDateTime: nil, estimatedDurationMinutes: nil, category: nil, project: nil,
                tags: nil, color: nil, progressPercentage: nil, location: nil,
                latitude: nil, longitude: nil, isProModeEnabled: nil, isFuture: nil, subtasks: nil
            )
        }
    }

}

// MARK: - Task Card

private struct TaskCard: View {
    let task: Task
    let isCompleting: Bool
    let onTap: () -> Void
    let onComplete: () -> Void
    let onDelete: () -> Void
    let onStatusChange: (TaskStatus) -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var swipeOpen = false
    @State private var localSubtasks: [Subtask] = []
    @State private var isPresentingAddSubtask = false

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
        .onAppear { localSubtasks = task.subtasks }
        .onChange(of: task.subtasks) { _, newSubtasks in
            localSubtasks = newSubtasks
        }
        .sheet(isPresented: $isPresentingAddSubtask) {
            AddSubtaskSheet(parentTaskId: task.id) { text in
                withAnimation(.easeInOut(duration: 0.12)) {
                    localSubtasks.append(Subtask(text: text, completed: false, order: localSubtasks.count))
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(24)
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                statusMenuButton
                Spacer(minLength: 0)
                subtaskAddButton
                priorityFlag
            }

            labelsColumn

            if !localSubtasks.isEmpty {
                subtasksList
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(TasksKalshiStyle.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(TasksKalshiStyle.cardBorder, lineWidth: 1)
                )
        )
        .opacity(isCompleting ? 0.5 : 1)
        .contentShape(Rectangle())
        .onTapGesture {
            if swipeOpen {
                withAnimation(.easeInOut(duration: 0.12)) { dragOffset = 0; swipeOpen = false }
            } else { onTap() }
        }
        .contextMenu {
            Button { onComplete() } label: { Label("Complete", systemImage: "checkmark.circle") }
            Divider()
            Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
        }
    }

    // MARK: - Status Menu Button

    private var statusMenuButton: some View {
        Menu {
            ForEach([TaskStatus.pending, .inProgress, .onHold, .completed, .cancelled], id: \.self) { s in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onStatusChange(s)
                } label: {
                    Text(s.shortLabel)
                }
            }
        } label: {
            Text((isCompleting ? TaskStatus.completed : task.status).shortLabel)
                .font(.system(size: 10, weight: .bold))
                .kerning(0.6)
                .textCase(.uppercase)
                .foregroundStyle(statusFgColor(isCompleting ? .completed : task.status))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(statusBgColor(isCompleting ? .completed : task.status), in: Capsule())
                .animation(.easeInOut(duration: 0.12), value: isCompleting)
                .animation(.easeInOut(duration: 0.12), value: task.status)
        }
        .buttonStyle(.plain)
    }

    private func statusFgColor(_ s: TaskStatus) -> Color {
        switch s {
        case .pending:    return TasksKalshiStyle.secondaryText
        case .inProgress: return TasksKalshiStyle.today
        case .onHold:     return TasksKalshiStyle.warning
        case .completed:  return TasksKalshiStyle.done
        case .cancelled:  return TasksKalshiStyle.danger
        }
    }

    private func statusBgColor(_ s: TaskStatus) -> Color {
        switch s {
        case .pending:    return TasksKalshiStyle.surfaceMuted
        case .inProgress: return TasksKalshiStyle.today.opacity(0.12)
        case .onHold:     return TasksKalshiStyle.warning.opacity(0.12)
        case .completed:  return TasksKalshiStyle.done.opacity(0.12)
        case .cancelled:  return TasksKalshiStyle.danger.opacity(0.12)
        }
    }

    // MARK: - Labels

    private var labelsColumn: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(task.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isCompleting ? TasksKalshiStyle.secondaryText : TasksKalshiStyle.primaryText)
                .strikethrough(isCompleting)
                .lineLimit(2)

            HStack(spacing: 6) {
                if let due = task.dueDateTime {
                    Text(task.isOverdue ? "PAST DUE" : "DUE")
                        .font(.system(size: 9, weight: .semibold))
                        .kerning(0.4)
                        .foregroundStyle(dueTone)
                    Text(Self.relativeFormatter.localizedString(for: due, relativeTo: Date()))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(task.isOverdue ? TasksKalshiStyle.danger : TasksKalshiStyle.secondaryText)
                }
                if recurrence != nil {
                    Image(systemName: "repeat")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(TasksKalshiStyle.today)
                }
                if task.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(TasksKalshiStyle.warning)
                }
                if let cat = task.category, !cat.isEmpty {
                    Text("·").foregroundStyle(TasksKalshiStyle.tertiaryText)
                    Text(cat.uppercased())
                        .font(.system(size: 9, weight: .semibold))
                        .kerning(0.4)
                        .foregroundStyle(TasksKalshiStyle.tertiaryText)
                }
            }

            if !task.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(task.tags.prefix(3), id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(TasksKalshiStyle.secondaryText)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(TasksKalshiStyle.surfaceMuted, in: Capsule())
                    }
                }
            }
        }
    }

    // MARK: - Inline Subtasks

    private var subtaskAddButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            isPresentingAddSubtask = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 9, weight: .bold))
                Text("Add subtask")
                    .font(.system(size: 10, weight: .semibold))
                    .kerning(0.2)
            }
            .foregroundStyle(TasksKalshiStyle.tertiaryText)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .overlay(Capsule().stroke(TasksKalshiStyle.cardBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var subtasksList: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach($localSubtasks) { $subtask in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        subtask.completed.toggle()
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: subtask.completed ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 13))
                            .foregroundStyle(subtask.completed ? TasksKalshiStyle.done : TasksKalshiStyle.tertiaryText)
                            .animation(.easeInOut(duration: 0.15), value: subtask.completed)
                        Text(subtask.text)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(subtask.completed ? TasksKalshiStyle.tertiaryText : TasksKalshiStyle.secondaryText)
                            .strikethrough(subtask.completed, color: TasksKalshiStyle.tertiaryText)
                            .lineLimit(1)
                    }
                }
                .buttonStyle(.plain)
            }

            // Progress bar if there are subtasks
            let done = localSubtasks.filter(\.completed).count
            let total = localSubtasks.count
            if total > 0 {
                HStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(TasksKalshiStyle.surfaceMuted).frame(height: 3)
                            Capsule().fill(TasksKalshiStyle.done)
                                .frame(width: geo.size.width * CGFloat(done) / CGFloat(total), height: 3)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: done)
                        }
                    }
                    .frame(height: 3)
                    Text("\(done)/\(total)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(TasksKalshiStyle.tertiaryText)
                }
                .padding(.top, 2)
            }
        }
        .padding(.top, 2)
    }

    // MARK: - Priority

    @ViewBuilder
    private var priorityFlag: some View {
        switch task.priority {
        case .critical: priorityBadge("CRIT", color: TasksKalshiStyle.danger)
        case .high: priorityBadge("HIGH", color: TasksKalshiStyle.warning)
        case .medium: priorityBadge("MED", color: TasksKalshiStyle.today)
        case .low: priorityBadge("LOW", color: TasksKalshiStyle.tertiaryText)
        }
    }

    private func priorityBadge(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.system(size: 9, weight: .bold))
            .kerning(0.4)
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
    }

    private var dueTone: Color {
        if task.isOverdue && !task.isDueToday { return TasksKalshiStyle.danger }
        if task.isDueToday { return TasksKalshiStyle.today }
        return TasksKalshiStyle.secondaryText
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
                withAnimation(.easeInOut(duration: 0.12)) {
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
                withAnimation(.easeInOut(duration: 0.12)) { dragOffset = 0; swipeOpen = false }
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
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.red))
        .opacity(dragOffset < 0 ? min(abs(dragOffset) / CGFloat(30), 1) : 0)
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter(); f.unitsStyle = .abbreviated; return f
    }()
}
