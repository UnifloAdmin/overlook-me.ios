import SwiftUI

// MARK: - Add Subtask Sheet

struct AddSubtaskSheet: View {
    let parentTaskId: String
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.injected) private var container

    /// Called when the user confirms a new subtask. Passes back the new subtask title to be shown locally immediately.
    var onAdd: (String) -> Void

    @State private var title = ""
    @State private var notes = ""
    @State private var priority: SubTaskPriority = .medium
    @State private var status: SubTaskStatus = .pending

    @State private var hasDate = true
    @State private var dueDate = Date()
    @State private var hasTime = true
    @State private var dueTime = Calendar.current.date(bySettingHour: 23, minute: 59, second: 0, of: Date()) ?? Date()

    @State private var hasEstimatedDuration = false
    @State private var estimatedMinutes = 30
    
    @State private var assignedTo = ""

    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showAdvanced = false

    @FocusState private var focusedField: Field?
    private enum Field: Hashable { case title, notes, assignedTo }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    titleCard
                    dateTimeCard
                    statusPriorityCard
                    advancedToggleCard

                    if showAdvanced {
                        durationCard
                        assignmentCard
                    }

                    if let error = errorMessage {
                        errorCard(error)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 96)
            }
            .background(TasksKalshiStyle.pageBackground.ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("New Subtask")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(TasksKalshiStyle.secondaryText)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        _Concurrency.Task { await saveSubTask() }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .controlSize(.small)
                                .tint(TasksKalshiStyle.primaryText)
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(TasksKalshiStyle.primaryText)
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
                ToolbarItem(placement: .keyboard) {
                    Button("Done") { focusedField = nil }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(TasksKalshiStyle.primaryText)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .onAppear { focusedField = .title }
        }
    }

    // MARK: - Core Cards

    private var titleCard: some View {
        VStack(spacing: 0) {
            inputRow(
                icon: "checklist.unchecked",
                placeholder: "Subtask title",
                text: $title,
                field: .title,
                weight: .semibold,
                next: .notes
            )

            rowDivider

            inputRow(
                icon: "text.alignleft",
                placeholder: "Notes (optional)",
                text: $notes,
                field: .notes,
                axis: .vertical,
                lineLimit: 2...5,
                textColor: TasksKalshiStyle.secondaryText
            )
        }
        .tasksDataCard()
    }

    private var dateTimeCard: some View {
        sectionCard("Schedule") {
            toggleRow("Due date", icon: "calendar", isOn: $hasDate, iconColor: TasksKalshiStyle.danger)

            if hasDate {
                rowDivider
                dateSelectionRow

                rowDivider
                toggleRow("Add time", icon: "clock", isOn: $hasTime, iconColor: TasksKalshiStyle.today)

                if hasTime {
                    rowDivider
                    timeSelectionRow
                }
            }
        }
    }

    private var dateSelectionRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            compactDateRow("Date", selection: $dueDate, components: .date)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    quickChip("Today", isSelected: isToday) { setDate(daysToAdd: 0) }
                    quickChip("Tomorrow", isSelected: isTomorrow) { setDate(daysToAdd: 1) }
                    quickChip("Next Week", isSelected: isNextWeek) { setDate(daysToAdd: 7) }
                }
                .padding(.leading, 34)
            }
        }
    }
    
    private var timeSelectionRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            compactDateRow("Time", selection: $dueTime, components: .hourAndMinute)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    quickChip("Morning", isSelected: isTimeMatch(hour: 9, minute: 0)) { setTime(hour: 9, minute: 0) }
                    quickChip("Afternoon", isSelected: isTimeMatch(hour: 13, minute: 0)) { setTime(hour: 13, minute: 0) }
                    quickChip("Evening", isSelected: isTimeMatch(hour: 18, minute: 0)) { setTime(hour: 18, minute: 0) }
                    quickChip("Night", isSelected: isTimeMatch(hour: 23, minute: 59)) { setTime(hour: 23, minute: 59) }
                }
                .padding(.leading, 34)
            }
        }
    }
    
    private func quickChip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { action() }
        }) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isSelected ? TasksKalshiStyle.pageBackground : TasksKalshiStyle.primaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? TasksKalshiStyle.primaryText : TasksKalshiStyle.surfaceMuted, in: Capsule())
                .overlay(Capsule().stroke(isSelected ? Color.clear : TasksKalshiStyle.cardBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var statusPriorityCard: some View {
        VStack(spacing: 0) {
            sectionHeader("Status")
                .padding(.horizontal, 14)
                .padding(.top, 14)
            
            Menu {
                ForEach([SubTaskStatus.pending, .inProgress, .completed, .cancelled], id: \.self) { s in
                    Button {
                        status = s
                    } label: {
                        Label(statusLabel(s), systemImage: statusIcon(s))
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: statusIcon(status))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(TasksKalshiStyle.today)
                        .frame(width: 20)
                    Text(statusLabel(status))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(TasksKalshiStyle.primaryText)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(TasksKalshiStyle.tertiaryText)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
            }
            .buttonStyle(.plain)
            
            rowDivider

            sectionHeader("Priority")
                .padding(.horizontal, 14)
                .padding(.top, 14)
                
            HStack(spacing: 0) {
                ForEach([SubTaskPriority.low, .medium, .high, .critical], id: \.self) { p in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.easeInOut(duration: 0.12)) { priority = p }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: p == .low ? "flag" : "flag.fill")
                                .font(.system(size: 13, weight: .semibold))
                            Text(priorityLabel(p).uppercased())
                                .font(.system(size: 9, weight: .semibold))
                                .kerning(0.5)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background {
                            if priority == p {
                                RoundedRectangle(cornerRadius: 999, style: .continuous)
                                    .fill(priorityColor(p).opacity(0.12))
                            }
                        }
                        .foregroundStyle(priority == p ? priorityColor(p) : TasksKalshiStyle.secondaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
        }
        .tasksDataCard()
    }

    // MARK: - Advanced Cards

    private var durationCard: some View {
        sectionCard("Duration") {
            toggleRow("Estimated duration", icon: "timer", isOn: $hasEstimatedDuration, iconColor: TasksKalshiStyle.today)
            if hasEstimatedDuration {
                rowDivider
                HStack(spacing: 10) {
                    Image(systemName: "hourglass")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(TasksKalshiStyle.tertiaryText)
                        .frame(width: 20)
                    Stepper(value: $estimatedMinutes, in: 5...480, step: 5) {
                        HStack {
                            Text("Length")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(TasksKalshiStyle.primaryText)
                            Spacer()
                            Text("\(estimatedMinutes) min")
                                .font(.system(size: 12, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(TasksKalshiStyle.secondaryText)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var assignmentCard: some View {
        sectionCard("Assignment") {
            inputRow(icon: "person.crop.circle", placeholder: "Assigned To (User ID)", text: $assignedTo, field: .assignedTo)
        }
    }

    private var advancedToggleCard: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 0.12)) { showAdvanced.toggle() }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TasksKalshiStyle.tertiaryText)
                    .frame(width: 20)
                Text("More options")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TasksKalshiStyle.primaryText)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(TasksKalshiStyle.tertiaryText)
                    .rotationEffect(.degrees(showAdvanced ? 180 : 0))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .tasksDataCard()
    }

    private func errorCard(_ error: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundStyle(TasksKalshiStyle.danger)
            Text(error)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(TasksKalshiStyle.danger)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(TasksKalshiStyle.dangerBg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(TasksKalshiStyle.dangerSoft.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - Reusable Rows
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .kerning(0.6)
            .foregroundStyle(TasksKalshiStyle.tertiaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tasksDataCard()
    }

    private func inputRow(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        axis: Axis = .horizontal,
        lineLimit: ClosedRange<Int>? = nil,
        weight: Font.Weight = .medium,
        textColor: Color = TasksKalshiStyle.primaryText,
        next: Field? = nil
    ) -> some View {
        HStack(alignment: axis == .vertical ? .top : .center, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(TasksKalshiStyle.tertiaryText)
                .frame(width: 20)
                .padding(.top, axis == .vertical ? 2 : 0)

            if axis == .vertical {
                TextField(placeholder, text: text, axis: .vertical)
                    .font(.system(size: 13, weight: weight))
                    .lineLimit(lineLimit ?? 1...4)
                    .foregroundStyle(textColor)
                    .focused($focusedField, equals: field)
            } else {
                TextField(placeholder, text: text)
                    .font(.system(size: 13, weight: weight))
                    .foregroundStyle(textColor)
                    .focused($focusedField, equals: field)
                    .submitLabel(next != nil ? .next : .done)
                    .onSubmit { focusedField = next }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func toggleRow(_ title: String, icon: String, isOn: Binding<Bool>, iconColor: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 20)
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(TasksKalshiStyle.primaryText)
            Spacer()
            Toggle("", isOn: isOn.animation(.easeInOut(duration: 0.12)))
                .labelsHidden()
                .tint(TasksKalshiStyle.primaryText)
        }
        .padding(.vertical, 2)
    }

    private func compactDateRow(_ title: String, selection: Binding<Date>, components: DatePickerComponents) -> some View {
        HStack(spacing: 10) {
            Image(systemName: components == .date ? "calendar" : "clock")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(TasksKalshiStyle.tertiaryText)
                .frame(width: 20)
                
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .kerning(0.5)
                .foregroundStyle(TasksKalshiStyle.tertiaryText)
                
            Spacer()
            
            DatePicker("", selection: selection, displayedComponents: components)
                .labelsHidden()
        }
        .padding(.top, 4)
        .padding(.bottom, 2)
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(TasksKalshiStyle.divider)
            .frame(height: 1)
            .padding(.leading, 34)
    }

    // MARK: - Save

    private func saveSubTask() async {
        isSaving = true
        errorMessage = nil

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

        print("🔄 [AddSubtaskSheet] Saving subtask:")
        print("   parentTaskId: \(parentTaskId)")
        print("   title: \(title.trimmingCharacters(in: .whitespaces))")
        print("   status: \(status.rawValue)")
        print("   priority: \(priority.rawValue)")
        print("   dueDateTime: \(finalDue?.description ?? "nil")")

        await container.interactors.tasksInteractor.createSubTask(
            taskId: parentTaskId,
            title: title.trimmingCharacters(in: .whitespaces),
            description: notes.isEmpty ? nil : notes, // using 'notes' textfield for API 'description'
            status: status,
            priority: priority,
            estimatedDurationMinutes: hasEstimatedDuration ? estimatedMinutes : nil,
            dueDateTime: finalDue,
            assignedTo: assignedTo.isEmpty ? nil : assignedTo,
            notes: notes.isEmpty ? nil : notes // Also sending down in 'notes' for completeness since API has both
        )

        isSaving = false

        if container.appState.state.tasks.error == nil {
            print("✅ [AddSubtaskSheet] Subtask saved successfully")
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            // Immediately let parent know to show it locally
            onAdd(title.trimmingCharacters(in: .whitespaces))
            dismiss()
        } else {
            let errDesc = container.appState.state.tasks.error?.localizedDescription ?? "Unknown error"
            print("❌ [AddSubtaskSheet] Subtask save failed: \(errDesc)")
            errorMessage = errDesc
        }
    }

    // MARK: - Helpers

    private func priorityLabel(_ p: SubTaskPriority) -> String {
        switch p {
        case .critical: return "Critical"
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }

    private func priorityColor(_ p: SubTaskPriority) -> Color {
        switch p {
        case .critical: return TasksKalshiStyle.danger
        case .high: return TasksKalshiStyle.warning
        case .medium: return TasksKalshiStyle.today
        case .low: return TasksKalshiStyle.secondaryText
        }
    }
    
    private func statusLabel(_ s: SubTaskStatus) -> String {
        switch s {
        case .pending: return "Pending"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }

    private func statusIcon(_ s: SubTaskStatus) -> String {
        switch s {
        case .pending: return "circle"
        case .inProgress: return "arrow.trianglehead.clockwise"
        case .completed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle"
        }
    }

    // MARK: - Date/Time Helpers
    
    private var isToday: Bool { Calendar.current.isDateInToday(dueDate) }
    private var isTomorrow: Bool { Calendar.current.isDateInTomorrow(dueDate) }
    private var isNextWeek: Bool {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        if let nextWeek = cal.date(byAdding: .day, value: 7, to: today) {
            return cal.isDate(dueDate, inSameDayAs: nextWeek)
        }
        return false
    }

    private func isTimeMatch(hour: Int, minute: Int) -> Bool {
        let cal = Calendar.current
        let timeComps = cal.dateComponents([.hour, .minute], from: dueTime)
        return timeComps.hour == hour && timeComps.minute == minute
    }
    
    private func setDate(daysToAdd: Int) {
        if let newDate = Calendar.current.date(byAdding: .day, value: daysToAdd, to: Date()) {
            dueDate = newDate
        }
    }
    
    private func setTime(hour: Int, minute: Int) {
        if let newTime = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: dueTime) {
            dueTime = newTime
        }
    }
}
