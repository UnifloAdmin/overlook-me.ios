import SwiftUI
import UserNotifications

// Disambiguate between domain Task model and Swift Concurrency Task
typealias ConcurrencyTask = _Concurrency.Task

struct TaskDashboard: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.injected) private var container
    @EnvironmentObject private var tabBar: TabBarStyleStore
    @State private var isPresentingAddTask = false
    @State private var showFullInsight = false
    @State private var isBootstrapping = true
    @State private var isPresentingFilters = false
    @State private var selectedTask: Task?
    @State private var isPresentingViewTask = false
    
    private var tasks: [Task] { container.appState.state.tasks.tasks }
    private var isLoading: Bool { container.appState.state.tasks.isLoading }
    private var error: Error? { container.appState.state.tasks.error }

    private var activeTasks: [Task] {
        tasks.filter { $0.status != .completed && $0.status != .cancelled }
    }

    private var completedTasks: [Task] {
        tasks.filter { $0.status == .completed }
    }

    private var cancelledTasks: [Task] {
        tasks.filter { $0.status == .cancelled }
    }
    
    private var shouldShowInitialLoader: Bool {
        isBootstrapping && tasks.isEmpty
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            gradientLayer
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    headerPlaceholder
                    tasksSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 130)
                .padding(.bottom, 48)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
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
                HStack(spacing: 12) {
                    Button(action: { isPresentingFilters = true }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.title3.weight(.semibold))
                    }
                    .buttonStyle(.glass)
                    .tint(.primary)
                    .accessibilityLabel("Filter Tasks")

                    Button(action: { isPresentingAddTask = true }) {
                        Image(systemName: "plus")
                            .font(.title3.weight(.semibold))
                    }
                    .accessibilityLabel("Add Task")
                }
            }
        }
        .sheet(isPresented: $isPresentingAddTask) {
            AddNewTask()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isPresentingFilters) {
            NavigationStack {
                List {
                    NavigationLink("View Completed") {
                        List {
                            if completedTasks.isEmpty {
                                Text("No completed tasks yet.")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(completedTasks) { task in
                                    ModernTaskCard(task: task)
                                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                                        .listRowBackground(Color.clear)
                                }
                            }
                        }
                        .navigationTitle("Completed")
                        .navigationBarTitleDisplayMode(.inline)
                    }
                    NavigationLink("View Cancelled") {
                        List {
                            if cancelledTasks.isEmpty {
                                Text("No cancelled tasks yet.")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(cancelledTasks) { task in
                                    ModernTaskCard(task: task)
                                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                                        .listRowBackground(Color.clear)
                                }
                            }
                        }
                        .navigationTitle("Cancelled")
                        .navigationBarTitleDisplayMode(.inline)
                    }
                }
                .navigationTitle("Advanced Filters")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isPresentingFilters = false
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .accessibilityLabel("Close filters")
                    }
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isPresentingViewTask) {
            if let task = selectedTask {
                ViewTask(task: task)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
                    .presentationCornerRadius(28)
            }
        }
        .task {
            print("👀 [TaskDashboard] task modifier triggered")
            await loadTasks()
        }
        .refreshable {
            print("🔄 [TaskDashboard] Pull to refresh triggered")
            await loadTasks()
        }
    }
    
    @ViewBuilder
    private var tasksSection: some View {
        LazyVStack(spacing: 12) {
            if shouldShowInitialLoader || isLoading {
                loadingView
            } else if let error = error {
                errorView(error)
            } else if activeTasks.isEmpty {
                emptyTasksView
            } else {
                tasksList
            }
        }
    }
    
    private var tasksList: some View {
        ForEach(activeTasks) { task in
            ModernTaskCard(task: task)
                .onTapGesture {
                    selectedTask = task
                    isPresentingViewTask = true
                }
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
                refreshAsync()
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
    
    private func refreshAsync() {
        ConcurrencyTask.detached { @MainActor in
            await self.loadTasks()
        }
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
        
        await MainActor.run {
            isBootstrapping = false
        }
        
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
    @Environment(\.injected) private var container
    let task: Task
    @State private var isUpdatingStatus = false
    @State private var isPresentingNotifications = false
    @State private var notificationTitle: String
    @State private var notificationTimes: [Date]
    
    init(task: Task) {
        self.task = task
        _notificationTitle = State(initialValue: task.title)
        _notificationTimes = State(initialValue: [])
    }
    
    private static let dateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
    
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
            }
            .onAppear {
                print("🎴 [ModernTaskCard] Rendering task: \(task.title)")
                print("   - dueDateTime: \(task.dueDateTime?.description ?? "nil")")
                print("   - isOverdue: \(task.isOverdue)")
            }
            
            // Metadata
            VStack(alignment: .leading, spacing: 8) {
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

            analyticsPill
                .frame(maxWidth: .infinity, alignment: .center)
            
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

            HStack(spacing: 12) {
                statusFooter
                    .frame(maxWidth: .infinity)
                if shouldShowNotifications {
                    notificationButton
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.separator), lineWidth: 1)
        )
        .sheet(isPresented: $isPresentingNotifications) {
            notificationSheet
        }
        .onAppear {
            loadNotificationSettings()
        }
    }
    
    private var analyticsPill: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: priorityIcon)
                    .font(.subheadline.weight(.semibold))
                Text(priorityText)
                    .font(.caption.bold())
            }
            .foregroundStyle(priorityColor)
            
            Divider()
                .frame(height: 14)
            
            if let dueDate = task.dueDateTime {
                Label {
                    Text("Due \(formattedDate(dueDate))")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                } icon: {
                    Image(systemName: task.isOverdue ? "exclamationmark.triangle.fill" : "clock.fill")
                        .font(.caption)
                }
                .foregroundStyle(task.isOverdue ? Color.red : Color.orange)
            } else {
                Label {
                    Text("No due date")
                        .font(.caption.weight(.semibold))
                } icon: {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemFill).opacity(0.2), in: Capsule())
    }
    
    private var statusFooter: some View {
        Menu {
            ForEach(statusOptions, id: \.self) { status in
                Button {
                    updateStatus(status)
                } label: {
                    Label(statusText(for: status), systemImage: statusIcon(for: status))
                        .foregroundStyle(statusColor(for: status))
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: statusIcon)
                    .font(.subheadline)
                Text(statusText)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                if isUpdatingStatus {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .transaction { $0.animation = nil }
        }
        .buttonStyle(.plain)
        .disabled(isUpdatingStatus)
        .foregroundStyle(.white)
        .background(Color(.systemBlue), in: Capsule())
        .animation(nil, value: isUpdatingStatus)
    }

    private var notificationButton: some View {
        Button {
            isPresentingNotifications = true
        } label: {
            ZStack {
                Image(systemName: "bell")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .background(Color(uiColor: .secondarySystemFill))
                    .clipShape(Circle())
                
                if notificationTimes.count > 0 {
                    Text("\(notificationTimes.count)")
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
        .foregroundStyle(Color(.systemBlue))
        .accessibilityLabel("Notifications")
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
        statusColor(for: task.status)
    }
    
    private func statusColor(for status: TaskStatus) -> Color {
        switch status {
        case .pending: return .gray
        case .inProgress: return .blue
        case .completed: return .green
        case .cancelled: return .red
        case .onHold: return .orange
        }
    }
    
    private var statusIcon: String {
        statusIcon(for: task.status)
    }
    
    private var statusText: String {
        statusText(for: task.status)
    }

    private var statusOptions: [TaskStatus] {
        [.pending, .inProgress, .completed, .cancelled, .onHold]
    }

    private var shouldShowNotifications: Bool {
        task.status != .completed && task.status != .cancelled
    }
    
    private func statusIcon(for status: TaskStatus) -> String {
        switch status {
        case .pending: return "circle.dashed"
        case .inProgress: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        case .onHold: return "pause.circle.fill"
        }
    }
    
    private func statusText(for status: TaskStatus) -> String {
        switch status {
        case .pending: return "Pending"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        case .onHold: return "On Hold"
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        Self.dateFormatter.localizedString(for: date, relativeTo: Date())
    }

    private func updateStatus(_ status: TaskStatus) {
        guard status != task.status else { return }
        isUpdatingStatus = true
        ConcurrencyTask { @MainActor in
            await container.interactors.tasksInteractor.updateTask(
                taskId: task.id,
                title: nil,
                description: nil,
                descriptionFormat: nil,
                status: status,
                priority: nil,
                scheduledDate: nil,
                scheduledTime: nil,
                dueDateTime: nil,
                estimatedDurationMinutes: nil,
                category: nil,
                project: nil,
                tags: nil,
                color: nil,
                progressPercentage: nil,
                location: nil,
                latitude: nil,
                longitude: nil,
                isProModeEnabled: nil,
                isFuture: nil
            )
            isUpdatingStatus = false
        }
    }
    
    private var notificationSheet: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Notification title", text: $notificationTitle)
                }
                
                Section("Times") {
                    if notificationTimes.isEmpty {
                        Text("Add up to 5 notification times.")
                            .foregroundStyle(.secondary)
                    }
                    
                    ForEach(notificationTimes.indices, id: \.self) { index in
                        DatePicker(
                            "Time",
                            selection: Binding(
                                get: { notificationTimes[index] },
                                set: { newTime in
                                    notificationTimes[index] = newTime
                                    saveNotificationSettings()
                                }
                            ),
                            displayedComponents: [.hourAndMinute]
                        )
                        .datePickerStyle(.compact)
                    }
                    .onDelete(perform: removeNotificationTimes)
                    
                    Button {
                        addNotificationTime()
                    } label: {
                        Label("Add Time", systemImage: "plus")
                    }
                    .disabled(notificationTimes.count >= 5)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        saveNotificationSettings()
                        isPresentingNotifications = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            loadNotificationSettings()
            checkAuthorization()
        }
    }
    
    private func addNotificationTime() {
        guard notificationTimes.count < 5 else { return }
        notificationTimes.append(Date())
        saveNotificationSettings()
    }
    
    private func removeNotificationTimes(at offsets: IndexSet) {
        notificationTimes.remove(atOffsets: offsets)
        saveNotificationSettings()
    }

    private var notificationTimesKey: String {
        "task_notifications_\(task.id)"
    }

    private var notificationTitleKey: String {
        "task_notification_title_\(task.id)"
    }

    private func loadNotificationSettings() {
        if let saved = UserDefaults.standard.array(forKey: notificationTimesKey) as? [Date] {
            notificationTimes = saved
        }
        if let savedTitle = UserDefaults.standard.string(forKey: notificationTitleKey), !savedTitle.isEmpty {
            notificationTitle = savedTitle
        }
    }

    private func saveNotificationSettings() {
        UserDefaults.standard.set(notificationTimes, forKey: notificationTimesKey)
        UserDefaults.standard.set(notificationTitle, forKey: notificationTitleKey)
        ConcurrencyTask {
            await scheduleNotifications()
        }
    }

    private func checkAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus != .authorized {
                requestAuthorization()
            }
        }
    }

    private func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    private func scheduleNotifications() async {
        let center = UNUserNotificationCenter.current()
        let identifiersToRemove = (await center.pendingNotificationRequests())
            .filter { $0.identifier.starts(with: "task_\(task.id)_") }
            .map { $0.identifier }
        center.removePendingNotificationRequests(withIdentifiers: identifiersToRemove)

        guard !notificationTimes.isEmpty else { return }

        for (index, date) in notificationTimes.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = notificationTitle.isEmpty ? task.title : notificationTitle
            content.body = "Don't forget to work on \(task.title)."
            content.sound = .default

            let components = Calendar.current.dateComponents([.hour, .minute], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

            let request = UNNotificationRequest(
                identifier: "task_\(task.id)_\(index)",
                content: content,
                trigger: trigger
            )

            try? await center.add(request)
        }
    }
}

// MARK: - Background Layers

private extension TaskDashboard {
    @ViewBuilder
    var gradientLayer: some View {
        VStack(spacing: 0) {
            TasksPalette.headerGradient(for: colorScheme)
                .frame(height: 280)
                .overlay(TasksPalette.highlightGradient(for: colorScheme))
                .overlay(TasksPalette.glossOverlay(for: colorScheme))
                .overlay(alignment: .bottom) {
                    TasksPalette.fadeOverlay(for: colorScheme)
                        .frame(height: 98)
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
    
    static func cardBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(uiColor: .secondarySystemBackground) : Color(.systemBackground)
    }
    
    static func cardShadow(for colorScheme: ColorScheme) -> Color {
        Color.black.opacity(colorScheme == .dark ? 0.45 : 0.08)
    }
}
