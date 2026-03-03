import SwiftUI

struct AddNewTask: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.injected) private var container

    @State private var title = ""
    @State private var notes = ""
    @State private var priority: TaskPriority = .medium

    @State private var hasDate = false
    @State private var dueDate = Date()
    @State private var hasTime = false
    @State private var dueTime = Date()

    @State private var recurrenceFrequency: RecurrenceFrequency?
    @State private var recurrenceEndDate: Date?
    @State private var hasRecurrenceEnd = false

    @State private var hasEstimatedDuration = false
    @State private var estimatedMinutes = 30

    @State private var category = ""
    @State private var project = ""
    @State private var tagsText = ""

    @State private var hasLocation = false
    @State private var location = ""

    @State private var selectedColor = "#007AFF"
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showAdvanced = false

    @FocusState private var titleFocused: Bool

    private let colors = ["#007AFF", "#FF9500", "#FF3B30", "#34C759", "#5856D6", "#FF2D55", "#5AC8FA", "#FFCC00"]

    var body: some View {
        NavigationStack {
            Form {
                titleSection
                dateTimeSection
                repeatSection
                prioritySection

                if showAdvanced {
                    durationSection
                    organizationSection
                    colorSection
                    locationSection
                }

                advancedToggle

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        _Concurrency.Task { await saveTask() }
                    } label: {
                        if isSaving {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Add").bold()
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
            .onAppear { titleFocused = true }
        }
    }

    // MARK: - Title

    private var titleSection: some View {
        Section {
            TextField("Title", text: $title)
                .font(.title3.weight(.semibold))
                .focused($titleFocused)

            TextField("Notes", text: $notes, axis: .vertical)
                .font(.body)
                .lineLimit(2...5)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Date & Time

    private var dateTimeSection: some View {
        Section {
            Toggle(isOn: $hasDate.animation(.spring(response: 0.3))) {
                Label("Date", systemImage: "calendar")
                    .foregroundStyle(.red)
            }

            if hasDate {
                DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))

                Toggle(isOn: $hasTime.animation(.spring(response: 0.3))) {
                    Label("Time", systemImage: "clock")
                        .foregroundStyle(.blue)
                }

                if hasTime {
                    DatePicker("Time", selection: $dueTime, displayedComponents: .hourAndMinute)
                        .transition(.opacity)
                }
            }
        }
    }

    // MARK: - Repeat

    private var repeatSection: some View {
        Section {
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
                Toggle(isOn: $hasRecurrenceEnd.animation(.spring(response: 0.3))) {
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
        }
    }

    // MARK: - Priority

    private var prioritySection: some View {
        Section {
            HStack(spacing: 0) {
                ForEach([TaskPriority.low, .medium, .high, .critical], id: \.self) { p in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.25)) { priority = p }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: p == .low ? "flag" : "flag.fill")
                                .font(.body)
                                .symbolEffect(.bounce, value: priority == p)
                            Text(priorityLabel(p))
                                .font(.caption2.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background {
                            if priority == p {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(priorityColor(p).opacity(0.12))
                            }
                        }
                        .foregroundStyle(priority == p ? priorityColor(p) : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        } header: {
            Text("Priority")
        }
    }

    // MARK: - Duration

    private var durationSection: some View {
        Section {
            Toggle(isOn: $hasEstimatedDuration.animation(.spring(response: 0.3))) {
                Label("Duration", systemImage: "timer")
                    .foregroundStyle(.teal)
            }
            if hasEstimatedDuration {
                Stepper(value: $estimatedMinutes, in: 5...480, step: 5) {
                    HStack {
                        Text("Estimated")
                        Spacer()
                        Text("\(estimatedMinutes) min")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                .transition(.opacity)
            }
        }
    }

    // MARK: - Organization

    private var organizationSection: some View {
        Section("Organization") {
            HStack {
                Image(systemName: "folder")
                    .foregroundStyle(.purple)
                TextField("Category", text: $category)
            }
            HStack {
                Image(systemName: "briefcase")
                    .foregroundStyle(.indigo)
                TextField("Project", text: $project)
            }
            HStack {
                Image(systemName: "tag")
                    .foregroundStyle(.teal)
                TextField("Tags (comma separated)", text: $tagsText)
            }
        }
    }

    // MARK: - Color

    private var colorSection: some View {
        Section("Color") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(colors, id: \.self) { hex in
                        Button {
                            UISelectionFeedbackGenerator().selectionChanged()
                            selectedColor = hex
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 34, height: 34)
                                if selectedColor == hex {
                                    Circle()
                                        .strokeBorder(.white, lineWidth: 2.5)
                                        .frame(width: 34, height: 34)
                                    Image(systemName: "checkmark")
                                        .font(.caption2.bold())
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .scaleEffect(selectedColor == hex ? 1.15 : 1)
                        .animation(.spring(response: 0.25), value: selectedColor)
                    }
                }
                .padding(.vertical, 6)
            }
        }
    }

    // MARK: - Location

    private var locationSection: some View {
        Section {
            Toggle(isOn: $hasLocation.animation(.spring(response: 0.3))) {
                Label("Location", systemImage: "location")
                    .foregroundStyle(.green)
            }
            if hasLocation {
                TextField("Location name", text: $location)
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Advanced Toggle

    private var advancedToggle: some View {
        Section {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.35)) { showAdvanced.toggle() }
            } label: {
                HStack {
                    Label("More Options", systemImage: "ellipsis.circle")
                    Spacer()
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(showAdvanced ? 180 : 0))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Save

    private func saveTask() async {
        isSaving = true
        errorMessage = nil

        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"

        var finalDue: Date?
        if hasDate {
            var cal = Calendar.current
            cal.timeZone = .current
            var comps = cal.dateComponents([.year, .month, .day], from: dueDate)
            if hasTime {
                let timeComps = cal.dateComponents([.hour, .minute], from: dueTime)
                comps.hour = timeComps.hour
                comps.minute = timeComps.minute
            }
            finalDue = cal.date(from: comps)
        }

        await container.interactors.tasksInteractor.createTask(
            title: title.trimmingCharacters(in: .whitespaces),
            description: notes.isEmpty ? nil : notes,
            descriptionFormat: "plain",
            status: .pending,
            priority: priority,
            scheduledDate: now,
            scheduledTime: formatter.string(from: now),
            dueDateTime: finalDue,
            estimatedDurationMinutes: hasEstimatedDuration ? estimatedMinutes : nil,
            category: category.isEmpty ? nil : category,
            project: project.isEmpty ? nil : project,
            tags: tagsText.isEmpty ? nil : tagsText,
            color: selectedColor,
            location: hasLocation ? location : nil,
            latitude: nil,
            longitude: nil,
            isProModeEnabled: false,
            isFuture: false
        )

        if let freq = recurrenceFrequency,
           let newId = container.appState.state.tasks.lastCreatedTaskId {
            let recurrence = TaskRecurrence(
                frequency: freq,
                endDate: hasRecurrenceEnd ? recurrenceEndDate : nil
            )
            RecurrenceStore.set(recurrence, for: newId)
        }

        isSaving = false

        if container.appState.state.tasks.error == nil {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        } else {
            errorMessage = container.appState.state.tasks.error?.localizedDescription
        }
    }

    // MARK: - Helpers

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
        case .critical: return .red
        case .high: return .orange
        case .medium: return .blue
        case .low: return .green
        }
    }
}

#Preview {
    AddNewTask()
        .environment(\.injected, DIContainer(appState: Store(AppState()), interactors: .stub))
}
