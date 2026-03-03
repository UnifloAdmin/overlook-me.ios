import SwiftUI

struct TaskBacklogsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.injected) private var container

    @State private var selectedFilter: BacklogFilter = .completed
    @State private var searchText = ""

    private var tasks: [Task] { container.appState.state.tasks.tasks }

    private var filteredTasks: [Task] {
        let base: [Task]
        switch selectedFilter {
        case .completed: base = tasks.filter { $0.status == .completed }.sorted { $0.updatedAt > $1.updatedAt }
        case .cancelled: base = tasks.filter { $0.status == .cancelled }.sorted { $0.updatedAt > $1.updatedAt }
        case .onHold: base = tasks.filter { $0.status == .onHold }.sorted { $0.updatedAt > $1.updatedAt }
        }
        guard !searchText.isEmpty else { return base }
        return base.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    enum BacklogFilter: String, CaseIterable, Identifiable {
        case completed, cancelled, onHold
        var id: String { rawValue }
        var label: String {
            switch self {
            case .completed: return "Completed"; case .cancelled: return "Cancelled"; case .onHold: return "On Hold"
            }
        }
        var icon: String {
            switch self {
            case .completed: return "checkmark.circle.fill"; case .cancelled: return "xmark.circle.fill"; case .onHold: return "pause.circle.fill"
            }
        }
        var tint: Color {
            switch self {
            case .completed: return .green; case .cancelled: return .red; case .onHold: return .orange
            }
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemGroupedBackground).ignoresSafeArea()
            gradientLayer

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    headerStats
                    filterPicker
                    tasksList
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 130)
                .padding(.bottom, 48)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        }
        .ignoresSafeArea(edges: .top)
        .navigationTitle("Backlogs")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search backlogs")
    }

    // MARK: - Header

    private var headerStats: some View {
        HStack(spacing: 16) {
            statBubble(count: tasks.filter { $0.status == .completed }.count, label: "Done", color: .green)
            statBubble(count: tasks.filter { $0.status == .cancelled }.count, label: "Cancelled", color: .red)
            statBubble(count: tasks.filter { $0.status == .onHold }.count, label: "On Hold", color: .orange)
        }
        .padding(.horizontal, 4)
    }

    private func statBubble(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(headerTextColor)
                .contentTransition(.numericText(value: Double(count)))
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(headerTextColor.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }

    private var headerTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.9) : .white
    }

    // MARK: - Filter

    private var filterPicker: some View {
        Picker("Filter", selection: $selectedFilter.animation(.spring(response: 0.3))) {
            ForEach(BacklogFilter.allCases) { f in
                Label(f.label, systemImage: f.icon).tag(f)
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
                    .foregroundStyle(.tertiary)
                Text("No \(selectedFilter.label.lowercased()) tasks")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        } else {
            HStack(spacing: 6) {
                Text("\(filteredTasks.count) \(selectedFilter.label)")
                    .font(.subheadline.bold())
                    .foregroundStyle(selectedFilter.tint)
                    .textCase(.uppercase)
            }
            .padding(.leading, 4)

            VStack(spacing: 10) {
                ForEach(filteredTasks) { task in
                    BacklogCard(
                        task: task,
                        filter: selectedFilter,
                        colorScheme: colorScheme,
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
                latitude: nil, longitude: nil, isProModeEnabled: nil, isFuture: nil
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

    // MARK: - Gradient

    private var gradientLayer: some View {
        VStack(spacing: 0) {
            BacklogsPalette.headerGradient(for: colorScheme)
                .frame(height: 280)
                .overlay(BacklogsPalette.highlightGradient(for: colorScheme))
                .overlay(BacklogsPalette.glossOverlay(for: colorScheme))
                .overlay(alignment: .bottom) {
                    BacklogsPalette.fadeOverlay(for: colorScheme).frame(height: 98)
                }
                .frame(maxWidth: .infinity)
            Spacer()
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

// MARK: - Backlog Card

private struct BacklogCard: View {
    let task: Task
    let filter: TaskBacklogsView.BacklogFilter
    let colorScheme: ColorScheme
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
                    .font(.subheadline.weight(.semibold))
                    .strikethrough(filter == .completed)
                    .foregroundStyle(filter == .cancelled ? .secondary : .primary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    if let cat = task.category, !cat.isEmpty {
                        Text(cat).font(.caption2.weight(.medium)).foregroundStyle(.tertiary)
                        Text("·").foregroundStyle(.quaternary)
                    }
                    Text(Self.dateFormatter.string(from: task.updatedAt))
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 0)

            Text(task.priority.rawValue.capitalized)
                .font(.caption2.bold())
                .foregroundStyle(priorityColor(task.priority))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(BacklogsPalette.cardBackground(for: colorScheme))
                .shadow(color: BacklogsPalette.cardShadow(for: colorScheme), radius: 5, y: 3)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if swipeDirection != .none {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { dragOffset = 0; swipeDirection = .none }
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
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
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
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { dragOffset = 0; swipeDirection = .none }
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
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { dragOffset = 0; swipeDirection = .none }
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
        switch p { case .critical: return .red; case .high: return .orange; case .medium: return .blue; case .low: return .gray }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none; return f
    }()
}

// MARK: - Palette

private enum BacklogsPalette {
    private static let warm = Color(uiColor: .systemOrange).opacity(0.75)
    private static let amber = Color(uiColor: .systemYellow).opacity(0.65)
    private static let sage = Color(uiColor: .systemGreen).opacity(0.55)
    private static let slate = Color(uiColor: .systemGray).opacity(0.5)

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
        cs == .dark ? [warm.opacity(0.65), amber.opacity(0.5), sage.opacity(0.45), slate.opacity(0.4)] : [warm, amber, sage, slate]
    }
}
