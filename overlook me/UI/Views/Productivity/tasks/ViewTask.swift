import SwiftUI

struct ViewTask: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.injected) private var container

    let task: Task

    @State private var editedTitle: String
    @State private var editedNotes: String
    @State private var editedPriority: TaskPriority
    @State private var editedStatus: TaskStatus
    @State private var editedCategory: String
    @State private var editedProject: String
    @State private var editedProgress: Double
    @State private var editedDueDate: Date
    @State private var hasDueDate: Bool

    @State private var recurrenceFrequency: RecurrenceFrequency?
    @State private var recurrenceEndDate: Date?
    @State private var hasRecurrenceEnd = false

    @State private var isSaving = false
    @State private var showDeleteConfirmation = false
    @State private var hasChanges = false

    init(task: Task) {
        self.task = task
        _editedTitle = State(initialValue: task.title)
        _editedNotes = State(initialValue: task.description ?? "")
        _editedPriority = State(initialValue: task.priority)
        _editedStatus = State(initialValue: task.status)
        _editedCategory = State(initialValue: task.category ?? "")
        _editedProject = State(initialValue: task.project ?? "")
        _editedProgress = State(initialValue: Double(task.progressPercentage))
        _editedDueDate = State(initialValue: task.dueDateTime ?? Date())
        _hasDueDate = State(initialValue: task.dueDateTime != nil)

        let recurrence = RecurrenceStore.get(for: task.id)
        _recurrenceFrequency = State(initialValue: recurrence?.frequency)
        _recurrenceEndDate = State(initialValue: recurrence?.endDate)
        _hasRecurrenceEnd = State(initialValue: recurrence?.endDate != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                statusSection
                titleSection
                scheduleSection
                progressSection
                organizationSection
                tagsSection
                locationSection
                infoSection
                deleteSection
            }
            .scrollContentBackground(.hidden)
            .background(TasksKalshiStyle.pageBackground)
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if hasChanges {
                        Button {
                            _Concurrency.Task { await saveChanges() }
                        } label: {
                            if isSaving {
                                ProgressView().controlSize(.small)
                            } else {
                                Text("Save")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .confirmationDialog("Delete this task?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { deleteTask() }
            }
            .animation(.easeInOut(duration: 0.12), value: hasChanges)
            .onChange(of: editedTitle) { trackChange() }
            .onChange(of: editedNotes) { trackChange() }
            .onChange(of: editedPriority) { trackChange() }
            .onChange(of: editedStatus) { trackChange() }
            .onChange(of: editedCategory) { trackChange() }
            .onChange(of: editedProject) { trackChange() }
            .onChange(of: editedProgress) { trackChange() }
            .onChange(of: hasDueDate) { trackChange() }
            .onChange(of: editedDueDate) { trackChange() }
            .onChange(of: recurrenceFrequency) { trackChange() }
        }
    }

    // MARK: - Status

    private var statusSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: statusIcon(editedStatus))
                    .font(.title3)
                    .foregroundStyle(statusColor(editedStatus))

                VStack(alignment: .leading, spacing: 2) {
                    Text(statusLabel(editedStatus))
                        .font(.headline)
                    if task.isOverdue {
                        Text("Overdue")
                            .font(.caption.bold())
                            .foregroundStyle(.red)
                    }
                }

                Spacer()

                Menu {
                    ForEach([TaskStatus.pending, .inProgress, .completed, .onHold, .cancelled], id: \.self) { s in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation { editedStatus = s }
                        } label: {
                            Label(statusLabel(s), systemImage: statusIcon(s))
                        }
                    }
                } label: {
                    Text("Change")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(statusColor(editedStatus).opacity(0.12), in: Capsule())
                        .foregroundStyle(statusColor(editedStatus))
                }
            }
        }
    }

    // MARK: - Title

    private var titleSection: some View {
        Section {
            TextField("Title", text: $editedTitle)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(TasksKalshiStyle.primaryText)

            TextField("Notes", text: $editedNotes, axis: .vertical)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(TasksKalshiStyle.secondaryText)
                .lineLimit(3...8)
        }
    }

    // MARK: - Schedule

    private var scheduleSection: some View {
        Section {
            Toggle(isOn: $hasDueDate.animation(.easeInOut(duration: 0.12))) {
                Label("Due Date", systemImage: "calendar")
                    .foregroundStyle(.red)
            }

            if hasDueDate {
                DatePicker("Date & Time", selection: $editedDueDate, displayedComponents: [.date, .hourAndMinute])
                    .transition(.opacity)
            }

            Picker(selection: $recurrenceFrequency) {
                Text("Never").tag(RecurrenceFrequency?.none)
                ForEach(RecurrenceFrequency.allCases) { freq in
                    Label(freq.label, systemImage: freq.icon).tag(Optional(freq))
                }
            } label: {
                Label("Repeat", systemImage: "repeat")
                    .foregroundStyle(.purple)
            }

            if recurrenceFrequency != nil {
                Toggle(isOn: $hasRecurrenceEnd.animation(.easeInOut(duration: 0.12))) {
                    Label("End Repeat", systemImage: "calendar.badge.minus")
                        .foregroundStyle(.orange)
                }
                if hasRecurrenceEnd {
                    DatePicker("End Date", selection: Binding(
                        get: { recurrenceEndDate ?? Calendar.current.date(byAdding: .month, value: 3, to: Date())! },
                        set: { recurrenceEndDate = $0 }
                    ), displayedComponents: .date)
                    .transition(.opacity)
                }
            }

            // Priority
            VStack(alignment: .leading, spacing: 8) {
                Text("Priority")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 0) {
                    ForEach([TaskPriority.low, .medium, .high, .critical], id: \.self) { p in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.easeInOut(duration: 0.12)) { editedPriority = p }
                        } label: {
                            VStack(spacing: 3) {
                                Image(systemName: p == .low ? "flag" : "flag.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                Text(priorityLabel(p))
                                    .font(.system(size: 10, weight: .semibold))
                                    .kerning(0.6)
                                    .textCase(.uppercase)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .foregroundStyle(editedPriority == p ? priorityColor(p) : TasksKalshiStyle.secondaryText)
                            .background {
                                if editedPriority == p {
                                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                                        .fill(priorityColor(p).opacity(0.12))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
        }
    }

    // MARK: - Progress

    private var progressSection: some View {
        Section {
            VStack(spacing: 8) {
                HStack {
                    Label("Progress", systemImage: "chart.bar.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(editedProgress))%")
                        .font(.subheadline.bold())
                        .monospacedDigit()
                        .contentTransition(.numericText(value: editedProgress))
                        .foregroundStyle(progressColor)
                }

                Slider(value: $editedProgress, in: 0...100, step: 5)
                    .tint(progressColor)
                    .onChange(of: editedProgress) {
                        UISelectionFeedbackGenerator().selectionChanged()
                    }

                ProgressView(value: editedProgress, total: 100)
                    .tint(progressColor)
                    .animation(.easeInOut(duration: 0.12), value: editedProgress)
            }
        }
    }

    // MARK: - Organization

    private var organizationSection: some View {
        Section("Organization") {
            HStack(spacing: 8) {
                Image(systemName: "folder").foregroundStyle(.purple)
                TextField("Category", text: $editedCategory)
            }
            HStack(spacing: 8) {
                Image(systemName: "briefcase").foregroundStyle(.indigo)
                TextField("Project", text: $editedProject)
            }
        }
    }

    // MARK: - Tags

    @ViewBuilder
    private var tagsSection: some View {
        if !task.tags.isEmpty {
            Section("Tags") {
                FlowLayout(spacing: 6) {
                    ForEach(task.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 10, weight: .semibold))
                            .kerning(0.6)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(TasksKalshiStyle.todayBg, in: Capsule())
                            .foregroundStyle(TasksKalshiStyle.today)
                    }
                }
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
            }
        }
    }

    // MARK: - Location

    @ViewBuilder
    private var locationSection: some View {
        if let loc = task.location, !loc.isEmpty {
            Section {
                Label(loc, systemImage: "location.fill")
                    .foregroundStyle(.green)
            }
        }
    }

    // MARK: - Info

    private var infoSection: some View {
        Section {
            LabeledContent("Created", value: Self.dateFormatter.string(from: task.createdAt))
            LabeledContent("Updated", value: Self.dateFormatter.string(from: task.updatedAt))
            if let dur = task.estimatedDurationMinutes {
                LabeledContent("Estimated", value: "\(dur) min")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    // MARK: - Delete

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Label("Delete Task", systemImage: "trash")
                        .font(.body.weight(.medium))
                    Spacer()
                }
            }
        }
    }

    // MARK: - Actions

    private func trackChange() { hasChanges = true }

    private func saveChanges() async {
        isSaving = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        await container.interactors.tasksInteractor.updateTask(
            taskId: task.id,
            title: editedTitle,
            description: editedNotes.isEmpty ? nil : editedNotes,
            descriptionFormat: "plain",
            status: editedStatus,
            priority: editedPriority,
            scheduledDate: nil,
            scheduledTime: nil,
            dueDateTime: hasDueDate ? editedDueDate : nil,
            estimatedDurationMinutes: nil,
            category: editedCategory.isEmpty ? nil : editedCategory,
            project: editedProject.isEmpty ? nil : editedProject,
            tags: nil,
            color: nil,
            progressPercentage: Int(editedProgress),
            location: nil,
            latitude: nil,
            longitude: nil,
            isProModeEnabled: nil,
            isFuture: nil,
            subtasks: nil
        )

        if let freq = recurrenceFrequency {
            RecurrenceStore.set(TaskRecurrence(frequency: freq, endDate: hasRecurrenceEnd ? recurrenceEndDate : nil), for: task.id)
        } else {
            RecurrenceStore.set(nil, for: task.id)
        }

        isSaving = false
        hasChanges = false
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func deleteTask() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        _Concurrency.Task { @MainActor in
            await container.interactors.tasksInteractor.deleteTask(taskId: task.id)
            RecurrenceStore.set(nil, for: task.id)
            dismiss()
        }
    }

    // MARK: - Helpers

    private var progressColor: Color {
        switch editedProgress {
        case 0..<25: return TasksKalshiStyle.danger
        case 25..<50: return TasksKalshiStyle.warning
        case 50..<75: return TasksKalshiStyle.secondaryText
        case 75..<100: return TasksKalshiStyle.today
        default: return TasksKalshiStyle.done
        }
    }

    private func statusIcon(_ s: TaskStatus) -> String {
        switch s {
        case .pending: return "circle.dashed"
        case .inProgress: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        case .onHold: return "pause.circle.fill"
        }
    }

    private func statusLabel(_ s: TaskStatus) -> String {
        switch s {
        case .pending: return "Pending"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        case .onHold: return "On Hold"
        }
    }

    private func statusColor(_ s: TaskStatus) -> Color {
        switch s {
        case .pending: return TasksKalshiStyle.secondaryText
        case .inProgress: return TasksKalshiStyle.today
        case .completed: return TasksKalshiStyle.done
        case .cancelled: return TasksKalshiStyle.danger
        case .onHold: return TasksKalshiStyle.warning
        }
    }

    private func priorityLabel(_ p: TaskPriority) -> String {
        switch p {
        case .critical: return "Critical"
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
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
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (i, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[i].x, y: bounds.minY + result.positions[i].y), anchor: .topLeading, proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxW = proposal.width ?? .infinity
        var pts: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rh: CGFloat = 0

        for sv in subviews {
            let s = sv.sizeThatFits(.unspecified)
            if x + s.width > maxW, x > 0 { x = 0; y += rh + spacing; rh = 0 }
            pts.append(CGPoint(x: x, y: y))
            x += s.width + spacing
            rh = max(rh, s.height)
        }
        return (pts, CGSize(width: maxW, height: y + rh))
    }
}
