import SwiftUI

struct TaskBacklogsView: View {
    @Environment(\.injected) private var container

    @State private var selectedFilter: BacklogFilter = .unscheduled
    @State private var searchText = ""

    private var tasks: [Task] { container.appState.state.tasks.tasks }

    private var filteredTasks: [Task] {
        let base: [Task]
        switch selectedFilter {
        case .unscheduled:
            base = tasks
                .filter { $0.status == .pending && $0.dueDateTime == nil }
                .sorted { $0.updatedAt > $1.updatedAt }
        case .completed: base = tasks.filter { $0.status == .completed }.sorted { $0.updatedAt > $1.updatedAt }
        case .cancelled: base = tasks.filter { $0.status == .cancelled }.sorted { $0.updatedAt > $1.updatedAt }
        case .onHold: base = tasks.filter { $0.status == .onHold }.sorted { $0.updatedAt > $1.updatedAt }
        }
        guard !searchText.isEmpty else { return base }
        return base.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    enum BacklogFilter: String, CaseIterable, Identifiable {
        case unscheduled, completed, cancelled, onHold
        var id: String { rawValue }
        var label: String {
            switch self {
            case .unscheduled: return "Unscheduled"
            case .completed: return "Completed"
            case .cancelled: return "Cancelled"
            case .onHold: return "On Hold"
            }
        }
        var icon: String {
            switch self {
            case .unscheduled: return "tray.fill"
            case .completed: return "checkmark.circle.fill"
            case .cancelled: return "xmark.circle.fill"
            case .onHold: return "pause.circle.fill"
            }
        }
        var tint: Color {
            switch self {
            case .unscheduled: return TasksKalshiStyle.secondaryText
            case .completed: return .green
            case .cancelled: return .red
            case .onHold: return .orange
            }
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            TasksKalshiStyle.pageBackground.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    headerStats
                    filterPicker
                    tasksList
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 48)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        }
        .navigationTitle("Backlogs")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search backlogs")
    }

    // MARK: - Header

    private var headerStats: some View {
        HStack(spacing: 12) {
            statBubble(count: tasks.filter { $0.status == .pending && $0.dueDateTime == nil }.count, label: "Unscheduled", color: TasksKalshiStyle.secondaryText)
            statBubble(count: tasks.filter { $0.status == .completed }.count, label: "Done", color: .green)
            statBubble(count: tasks.filter { $0.status == .cancelled }.count, label: "Cancelled", color: .red)
            statBubble(count: tasks.filter { $0.status == .onHold }.count, label: "On Hold", color: .orange)
        }
        .padding(.horizontal, 4)
    }

    private func statBubble(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.system(size: 23, weight: .bold))
                .foregroundStyle(color)
                .contentTransition(.numericText(value: Double(count)))
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .kerning(0.6)
                .foregroundStyle(TasksKalshiStyle.secondaryText)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Filter

    private var filterPicker: some View {
        Picker("Filter", selection: $selectedFilter.animation(.easeInOut(duration: 0.12))) {
            ForEach(BacklogFilter.allCases) { f in
                Text(f.label).tag(f)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Tasks

    @ViewBuilder
    private var tasksList: some View {
        if filteredTasks.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: selectedFilter.icon)
                    .font(.system(size: 40))
                    .foregroundStyle(TasksKalshiStyle.tertiaryText)
                Text("No \(selectedFilter.label.lowercased()) tasks")
                    .font(.headline)
                    .foregroundStyle(TasksKalshiStyle.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .tasksDataCard(cornerRadius: 20)
        } else {
            HStack(spacing: 6) {
                Text("\(filteredTasks.count) \(selectedFilter.label)")
                    .font(.system(size: 10, weight: .semibold))
                    .kerning(0.6)
                    .foregroundStyle(selectedFilter.tint)
                    .textCase(.uppercase)
            }
            .padding(.leading, 4)

            VStack(spacing: 10) {
                ForEach(filteredTasks) { task in
                    BacklogCard(
                        task: task,
                        filter: selectedFilter,
                        onRestore: { restoreTask(task) },
                        onDelete: { deleteTask(task) }
                    )
                }
            }
        }
    }

    // MARK: - Actions

    private func restoreTask(_ task: Task) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        ConcurrencyTask { @MainActor in
            await container.interactors.tasksInteractor.updateTask(
                taskId: task.id, title: nil, description: nil, descriptionFormat: nil,
                status: .pending, priority: nil, scheduledDate: nil, scheduledTime: nil,
                dueDateTime: nil, estimatedDurationMinutes: nil, category: nil, project: nil,
                tags: nil, color: nil, progressPercentage: 0, location: nil,
                latitude: nil, longitude: nil, isProModeEnabled: nil, isFuture: nil, subtasks: nil
            )
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    private func deleteTask(_ task: Task) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        ConcurrencyTask { @MainActor in
            await container.interactors.tasksInteractor.deleteTask(taskId: task.id)
            RecurrenceStore.set(nil, for: task.id)
        }
    }

}

// MARK: - Backlog Card

private struct BacklogCard: View {
    let task: Task
    let filter: TaskBacklogsView.BacklogFilter
    let onRestore: () -> Void
    let onDelete: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var swipeDirection: SwipeDirection = .none
    private let swipeWidth: CGFloat = 72
    private let threshold: CGFloat = 50
    private enum SwipeDirection { case none, left, right }

    var body: some View {
        ZStack {
            restoreBackground
            deleteBackground
            cardContent
                .offset(x: dragOffset)
                .gesture(swipeGesture)
        }
        .clipped()
    }

    private var cardContent: some View {
        HStack(spacing: 14) {
            Image(systemName: filter.icon)
                .font(.title3)
                .foregroundStyle(filter.tint)

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.system(size: 14, weight: .semibold))
                    .strikethrough(filter == .completed)
                    .foregroundStyle(filter == .cancelled ? TasksKalshiStyle.secondaryText : TasksKalshiStyle.primaryText)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    if let cat = task.category, !cat.isEmpty {
                        Text(cat).font(.system(size: 10, weight: .medium)).foregroundStyle(TasksKalshiStyle.tertiaryText)
                        Text("·").foregroundStyle(TasksKalshiStyle.tertiaryText)
                    }
                    Text(Self.dateFormatter.string(from: task.updatedAt))
                        .font(.system(size: 10, weight: .medium)).foregroundStyle(TasksKalshiStyle.tertiaryText)
                }
            }

            Spacer(minLength: 0)

            Text(task.priority.rawValue.capitalized)
                .font(.system(size: 10, weight: .bold))
                .kerning(0.6)
                .foregroundStyle(priorityColor(task.priority))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(TasksKalshiStyle.surfaceMuted, in: Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(TasksKalshiStyle.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(TasksKalshiStyle.cardBorder, lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if swipeDirection != .none {
                withAnimation(.easeInOut(duration: 0.12)) { dragOffset = 0; swipeDirection = .none }
            }
        }
        .contextMenu {
            Button { onRestore() } label: { Label("Restore to Pending", systemImage: "arrow.uturn.backward") }
            Divider()
            Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
        }
    }

    // MARK: Swipe

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onChanged { v in
                var base: CGFloat = 0
                if swipeDirection == .right { base = swipeWidth }
                else if swipeDirection == .left { base = -swipeWidth }
                dragOffset = max(-swipeWidth - 30, min(base + v.translation.width, swipeWidth + 30))
            }
            .onEnded { v in
                let vel = v.predictedEndTranslation.width - v.translation.width
                let openRight = dragOffset > threshold / 2 || vel > 100
                let openLeft = dragOffset < -threshold / 2 || vel < -100
                withAnimation(.easeInOut(duration: 0.12)) {
                    if openRight { dragOffset = swipeWidth; swipeDirection = .right }
                    else if openLeft { dragOffset = -swipeWidth; swipeDirection = .left }
                    else { dragOffset = 0; swipeDirection = .none }
                }
            }
    }

    private var restoreBackground: some View {
        HStack {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.easeInOut(duration: 0.12)) { dragOffset = 0; swipeDirection = .none }
                onRestore()
            } label: {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .font(.body.weight(.semibold)).foregroundColor(.white)
                    .frame(width: swipeWidth).frame(maxHeight: .infinity)
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.blue))
        .opacity(dragOffset > 0 ? min(dragOffset / 30, 1) : 0)
    }

    private var deleteBackground: some View {
        HStack {
            Spacer()
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.easeInOut(duration: 0.12)) { dragOffset = 0; swipeDirection = .none }
                onDelete()
            } label: {
                Image(systemName: "trash.fill")
                    .font(.body.weight(.semibold)).foregroundColor(.white)
                    .frame(width: swipeWidth).frame(maxHeight: .infinity)
            }
            .buttonStyle(.plain)
        }
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.red))
        .opacity(dragOffset < 0 ? min(abs(dragOffset) / CGFloat(30), 1) : 0)
    }

    private func priorityColor(_ p: TaskPriority) -> Color {
        switch p {
        case .critical: return TasksKalshiStyle.danger
        case .high: return TasksKalshiStyle.warning
        case .medium: return TasksKalshiStyle.today
        case .low: return TasksKalshiStyle.secondaryText
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none; return f
    }()
}
