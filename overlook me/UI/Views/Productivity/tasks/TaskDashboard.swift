import SwiftUI

struct TaskDashboard: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.injected) private var container
    @EnvironmentObject private var tabBar: TabBarStyleStore
    @State private var isPresentingAddTask = false
    
    private var tasks: [Task] { container.appState.state.tasks.tasks }
    private var isLoading: Bool { container.appState.state.tasks.isLoading }
    private var error: Error? { container.appState.state.tasks.error }
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            gradientLayer
            
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    tasksSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 100)
                .padding(.bottom, 48)
            }
            .scrollBounceBehavior(.basedOnSize, axes: [.vertical])
        }
        .ignoresSafeArea(edges: .top)
        .navigationTitle("Tasks")
        .navigationBarTitleDisplayMode(.large)
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
                Button(action: { isPresentingAddTask = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                }
                .accessibilityLabel("Add Task")
            }
        }
        .fullScreenCover(isPresented: $isPresentingAddTask) {
            AddNewTask()
        }
        .onAppear {
            print("👀 [TaskDashboard] onAppear triggered")
            if tasks.isEmpty && !isLoading {
                _Concurrency.Task {
                    print("🚀 [TaskDashboard] Starting initial load from onAppear")
                    await loadTasks()
                }
            }
        }
        .refreshable {
            print("🔄 [TaskDashboard] Pull to refresh triggered")
            await loadTasks()
        }
    }
    
    @ViewBuilder
    private var tasksSection: some View {
        if isLoading {
            loadingView
        } else if let error = error {
            errorView(error)
        } else if tasks.isEmpty {
            emptyTasksView
        } else {
            tasksList
        }
    }
    
    private var tasksList: some View {
        ForEach(tasks) { task in
            ModernTaskCard(task: task)
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.blue)
            
            VStack(spacing: 8) {
                Text("Loading tasks...")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text("Fetching your task list")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.orange)
                .symbolEffect(.bounce)
            
            Text("Unable to load tasks")
                .font(.title3.bold())
            
            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                _Concurrency.Task {
                    await loadTasks()
                }
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private var emptyTasksView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checklist")
                .font(.system(size: 70))
                .foregroundStyle(.secondary)
                .symbolEffect(.pulse)
            
            VStack(spacing: 8) {
                Text("No tasks yet")
                    .font(.title2.bold())
                
                Text("Create your first task to get started")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Button {
                isPresentingAddTask = true
            } label: {
                Label("Create Task", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }
    
    private func loadTasks() async {
        print("🎯 [TaskDashboard] loadTasks() called")
        print("   Current tasks count: \(tasks.count)")
        print("   Is loading: \(isLoading)")
        print("   Has error: \(error != nil)")
        
        await container.interactors.tasksInteractor.loadTasks(
            status: nil,
            priority: nil,
            category: nil,
            project: nil,
            date: nil,
            isPinned: nil,
            isArchived: false,
            overdue: nil,
            includeCompleted: true
        )
        
        print("✅ [TaskDashboard] loadTasks() completed")
        print("   Final tasks count: \(tasks.count)")
        print("   Is loading: \(isLoading)")
        print("   Has error: \(error != nil)")
    }
    
    private func handleBackAction() {
        if tabBar.config == .productivity {
            tabBar.config = .default
        } else if tabBar.config == .tasks {
            tabBar.config = .default
        } else {
            dismiss()
        }
    }
}

// MARK: - Modern Task Card

struct ModernTaskCard: View {
    let task: Task
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Title + Status
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    
                    if let description = task.description, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .padding(.top, 2)
                    }
                }
                
                Spacer(minLength: 8)
                
                priorityBadge
            }
            
            // Status Badge
            statusBadge
            
            Divider()
                .padding(.vertical, 4)
            
            // Metadata
            VStack(alignment: .leading, spacing: 8) {
                if let scheduledDate = task.scheduledDate {
                    metadataRow(
                        icon: "calendar.circle.fill",
                        label: "Scheduled",
                        value: formattedDate(scheduledDate),
                        color: .blue
                    )
                }
                
                if let dueDate = task.dueDateTime {
                    metadataRow(
                        icon: task.isOverdue ? "exclamationmark.triangle.fill" : "clock.circle.fill",
                        label: "Due",
                        value: formattedDate(dueDate),
                        color: task.isOverdue ? .red : .orange
                    )
                }
                
                if let category = task.category, !category.isEmpty {
                    metadataRow(
                        icon: "folder.circle.fill",
                        label: "Category",
                        value: category,
                        color: .purple
                    )
                }
                
                if let project = task.project, !project.isEmpty {
                    metadataRow(
                        icon: "briefcase.circle.fill",
                        label: "Project",
                        value: project,
                        color: .indigo
                    )
                }
                
                if task.progressPercentage > 0 {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "chart.bar.fill")
                                .font(.subheadline)
                            Text("Progress")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Text("\(task.progressPercentage)%")
                                .font(.subheadline.bold())
                                .monospacedDigit()
                        }
                        .foregroundStyle(progressColor)
                        
                        ProgressView(value: Double(task.progressPercentage), total: 100)
                            .tint(progressColor)
                    }
                }
            }
            
            // Tags & Pins
            if !task.tags.isEmpty || task.isPinned {
                HStack(spacing: 8) {
                    ForEach(task.tags.prefix(3), id: \.self) { tag in
                        Text(tag)
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background {
                                Capsule()
                                    .fill(.teal.opacity(0.15))
                            }
                            .foregroundStyle(.teal)
                    }
                    
                    if task.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
    }
    
    private var priorityBadge: some View {
        VStack(spacing: 4) {
            Image(systemName: priorityIcon)
                .font(.title3)
            Text(priorityText)
                .font(.caption2.bold())
        }
        .frame(width: 60)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(priorityColor.opacity(0.15))
        }
        .foregroundStyle(priorityColor)
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(priorityColor.opacity(0.3), lineWidth: 1.5)
        }
    }
    
    private var statusBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: statusIcon)
                .font(.subheadline)
            Text(statusText)
                .font(.subheadline.weight(.semibold))
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(statusColor.opacity(0.15))
        }
        .foregroundStyle(statusColor)
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(statusColor.opacity(0.3), lineWidth: 1)
        }
    }
    
    private func metadataRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(color)
            
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }
    
    // MARK: - Helpers
    
    private var priorityColor: Color {
        switch task.priority {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .blue
        case .low: return .gray
        }
    }
    
    private var priorityIcon: String {
        switch task.priority {
        case .critical: return "exclamationmark.3"
        case .high: return "exclamationmark.2"
        case .medium: return "equal"
        case .low: return "arrow.down"
        }
    }
    
    private var priorityText: String {
        switch task.priority {
        case .critical: return "CRITICAL"
        case .high: return "HIGH"
        case .medium: return "MEDIUM"
        case .low: return "LOW"
        }
    }
    
    private var progressColor: Color {
        switch task.progressPercentage {
        case 0..<25: return .red
        case 25..<50: return .orange
        case 50..<75: return .yellow
        case 75..<100: return .blue
        default: return .green
        }
    }
    
    private var statusColor: Color {
        switch task.status {
        case .pending: return .gray
        case .inProgress: return .blue
        case .completed: return .green
        case .cancelled: return .red
        case .onHold: return .orange
        }
    }
    
    private var statusIcon: String {
        switch task.status {
        case .pending: return "circle.dashed"
        case .inProgress: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        case .onHold: return "pause.circle.fill"
        }
    }
    
    private var statusText: String {
        switch task.status {
        case .pending: return "Pending"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        case .onHold: return "On Hold"
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Background Layers

private extension TaskDashboard {
    @ViewBuilder
    private var gradientLayer: some View {
        VStack(spacing: 0) {
            TasksPalette.headerGradient(for: colorScheme)
                .frame(height: 200)
                .overlay(TasksPalette.highlightGradient(for: colorScheme))
                .overlay(TasksPalette.glossOverlay(for: colorScheme))
                .overlay(alignment: .bottom) {
                    TasksPalette.fadeOverlay(for: colorScheme)
                        .frame(height: 80)
                }
                .frame(maxWidth: .infinity)
            Spacer()
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

// MARK: - Palette

private enum TasksPalette {
    private static let blush = Color(uiColor: .systemPurple).opacity(0.85)
    private static let lilac = Color(uiColor: .systemIndigo).opacity(0.85)
    private static let periwinkle = Color(uiColor: .systemBlue).opacity(0.75)
    private static let teal = Color(uiColor: .systemTeal).opacity(0.6)
    
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
        let grouped = Color(.systemGroupedBackground)
        
        return LinearGradient(
            colors: [.clear, grouped],
            startPoint: .top,
            endPoint: .bottom
        )
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
