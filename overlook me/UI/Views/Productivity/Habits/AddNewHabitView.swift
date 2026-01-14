import SwiftUI

struct AddNewHabitView: View {
    @State private var activeError: HabitFormError?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.injected) private var container: DIContainer
    @StateObject private var viewModel = AddNewHabitViewModel()
    @State private var showAdvancedOptions: Bool = false
    
    private var currentUserId: String? {
        container.appState.state.auth.user?.id
    }
    
    private var saveDisabled: Bool {
        viewModel.draft.trimmedName.isEmpty || viewModel.isSaving
    }
    
    var body: some View {
        NavigationStack {
            Form {
                basicsSection
                
                if showAdvancedOptions {
                    cadenceSection
                    statusSection
                    goalSection
                    scheduleSection
                    classificationSection
                    visualsSection
                    tagsSection
                    motivationSection
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Create Habit")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .cancel) { dismiss() } label: {
                        Image(systemName: "xmark")
                            .imageScale(.medium)
                    }
                    .accessibilityLabel("Cancel")
                    .disabled(viewModel.isSaving)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: saveHabit) {
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Image(systemName: "checkmark")
                                .imageScale(.medium)
                        }
                    }
                    .accessibilityLabel("Save habit")
                    .disabled(saveDisabled)
                }
            }
        }
        .interactiveDismissDisabled(viewModel.isSaving)
        .alert("Unable to Save", isPresented: Binding(
            get: { activeError != nil },
            set: { newValue in
                if !newValue { activeError = nil }
            })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(activeError?.errorDescription ?? "")
        }
    }
    
    private var basicsSection: some View {
        Section {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.draft.trimmedName.isEmpty ? "Name your habit" : viewModel.draft.trimmedName)
                        .font(.headline)
                    Text(viewModel.draft.trimmedDescription.isEmpty ? "Describe why this habit matters." : viewModel.draft.trimmedDescription)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            } icon: {
                Image(systemName: viewModel.draft.icon.systemImage)
                    .foregroundStyle(viewModel.draft.color.color)
            }
            .padding(.vertical, 4)
            
            TextField("Name", text: binding(\.name))
                .textInputAutocapitalization(.words)
            
            TextField("Why does this matter?", text: binding(\.description), axis: .vertical)
                .lineLimit(2...4)
            
            Picker("Priority", selection: binding(\.priority)) {
                ForEach(HabitPriority.allCases) { priority in
                    Text(priority.displayValue).tag(priority)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            
            VStack(alignment: .leading, spacing: 4) {
                Toggle(isOn: $showAdvancedOptions.animation()) {
                    Text("Advanced options")
                        .font(.subheadline.weight(.semibold))
                }
                .tint(.accentColor)
                
                Text(showAdvancedOptions ? "Advanced fields are visible below." : "Need more controls? Toggle advanced options.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var cadenceSection: some View {
        Section("Cadence") {
            Picker("Frequency", selection: binding(\.frequency)) {
                ForEach(HabitFrequency.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.draft.frequency) { newValue in
                switch newValue {
                case .weekdays:
                    viewModel.draft.selectedWeekdays = HabitWeekday.weekdayPresetSet
                case .weekends:
                    viewModel.draft.selectedWeekdays = HabitWeekday.weekendPresetSet
                case .daily:
                    viewModel.draft.selectedWeekdays.removeAll()
                case .custom:
                    if viewModel.draft.selectedWeekdays.isEmpty {
                        viewModel.draft.selectedWeekdays = HabitWeekday.weekdayPresetSet
                    }
                }
            }
            
            switch viewModel.draft.frequency {
            case .daily:
                Text("We'll remind you every day.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            case .weekdays:
                Text("Applies Monday through Friday.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            case .weekends:
                Text("Applies Saturday and Sunday.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            case .custom:
                WeekdayChipGrid(selectedDays: viewModel.draft.selectedWeekdays) { day in
                    if viewModel.draft.selectedWeekdays.contains(day) {
                        viewModel.draft.selectedWeekdays.remove(day)
                    } else {
                        viewModel.draft.selectedWeekdays.insert(day)
                    }
                }
            }
        }
    }
    
    private var goalSection: some View {
        Section("Goals & Measurement") {
            Picker("Goal Type", selection: binding(\.goalType)) {
                ForEach(HabitGoalType.allCases) { type in
                    Text(type.label).tag(type)
                }
            }
            
            TextField("What does success look like?", text: binding(\.dailyGoal), axis: .vertical)
                .lineLimit(1...2)
            
            if viewModel.draft.goalType.supportsTargetValue {
                Stepper(
                    value: binding(\.targetValue),
                    in: 1...240,
                    step: goalStepValue
                ) {
                    Text(goalTargetDescription)
                }
            }
            
            if viewModel.draft.goalType.supportsUnit {
                TextField("Unit (e.g., km, minutes, reps)", text: binding(\.unit))
            }
        }
    }
    
    private var statusSection: some View {
        Section("Status & Reminders") {
            Toggle(viewModel.draft.isPositive ? "Positive habit" : "Habit to reduce", isOn: binding(\.isPositive))
            Toggle("Pinned", isOn: binding(\.isPinned))
            Toggle("Enable reminders", isOn: binding(\.remindersEnabled))
            
            Toggle("Indefinite habit", isOn: binding(\.isIndefinite))
                .onChange(of: viewModel.draft.isIndefinite) { newValue in
                    if newValue {
                        viewModel.draft.expiryDate = nil
                    } else if viewModel.draft.expiryDate == nil {
                        viewModel.draft.expiryDate = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
                    }
                }
            
            if !viewModel.draft.isIndefinite {
                DatePicker(
                    "Expiry date",
                    selection: Binding(
                        get: { viewModel.draft.expiryDate ?? Date() },
                        set: { viewModel.draft.expiryDate = $0 }
                    ),
                    in: Date()...,
                    displayedComponents: .date
                )
            }
        }
    }
    
    private var scheduleSection: some View {
        Section("Schedule & Timing") {
            Picker("Preferred time", selection: binding(\.preferredTime)) {
                ForEach(HabitPreferredTime.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.segmented)
            
            Toggle("Set a start date", isOn: startDateEnabledBinding)
            if viewModel.draft.startDate != nil {
                DatePicker(
                    "Start",
                    selection: nonOptionalDateBinding(\.startDate),
                    in: Date()...,
                    displayedComponents: .date
                )
            }
            
            Toggle("Set an end date", isOn: endDateEnabledBinding)
            if viewModel.draft.endDate != nil {
                DatePicker(
                    "End",
                    selection: nonOptionalDateBinding(\.endDate, defaultValue: defaultEndDate),
                    in: (viewModel.draft.startDate ?? Date())...,
                    displayedComponents: .date
                )
            }
            
            Toggle("Schedule a reminder time", isOn: scheduledTimeEnabledBinding)
            if viewModel.draft.scheduledTime != nil {
                DatePicker(
                    "Reminder time",
                    selection: nonOptionalDateBinding(\.scheduledTime, defaultValue: defaultScheduledTime),
                    displayedComponents: .hourAndMinute
                )
            }
        }
    }
    
    private var classificationSection: some View {
        Section("Classification") {
            Picker("Category", selection: Binding(
                get: { viewModel.draft.category },
                set: { viewModel.draft.category = $0 }
            )) {
                ForEach(HabitCategoryOption.all) { option in
                    Text(option.label).tag(option)
                }
            }
        }
    }
    
    private var visualsSection: some View {
        Section("Visuals") {
            Picker("Icon", selection: Binding(
                get: { viewModel.draft.icon },
                set: { viewModel.draft.icon = $0 }
            )) {
                ForEach(HabitIconOption.all) { option in
                    Label(option.materialName.replacingOccurrences(of: "_", with: " ").capitalized, systemImage: option.systemImage)
                        .tag(option)
                }
            }
            
            Picker("Color", selection: Binding(
                get: { viewModel.draft.color },
                set: { viewModel.draft.color = $0 }
            )) {
                ForEach(HabitColorOption.all) { option in
                    HStack {
                        Circle()
                            .fill(option.color)
                            .frame(width: 12, height: 12)
                        Text(option.label)
                    }
                    .tag(option)
                }
            }
        }
    }
    
    private var tagsSection: some View {
        Section("Tags") {
            TextField("Add comma-separated tags", text: binding(\.tags))
            Text("Use tags to group habits and for analytics filtering.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
    
    private var motivationSection: some View {
        Section {
            DisclosureGroup("Motivation & Rewards") {
                TextField("Motivation", text: binding(\.motivation))
                TextField("Reward", text: binding(\.reward))
            }
        }
    }
    
    private func saveHabit() {
        guard let userId = currentUserId else {
            activeError = .missingUser
            return
        }
        
_Concurrency.Task {
            do {
                _ = try await viewModel.save(userId: userId)
                dismiss()
            } catch let error as HabitFormError {
                activeError = error
            } catch {
                activeError = .network("Something went wrong. Please try again.")
            }
        }
    }
    
    private var goalTargetDescription: String {
        let value = Int(viewModel.draft.targetValue)
        switch viewModel.draft.goalType {
        case .duration:
            return "Target \(value) minutes per session"
        case .numeric:
            return "Target \(value) per \(viewModel.draft.frequency == .daily ? "day" : "week")"
        case .text, .boolean:
            return "Target \(value) completions"
        }
    }
    
    private var goalStepValue: Double {
        viewModel.draft.goalType == .duration ? 5.0 : 1.0
    }
    
    private var startDateEnabledBinding: Binding<Bool> {
        Binding(
            get: { viewModel.draft.startDate != nil },
            set: { enabled in
                viewModel.draft.startDate = enabled ? (viewModel.draft.startDate ?? Date()) : nil
            }
        )
    }
    
    private var endDateEnabledBinding: Binding<Bool> {
        Binding(
            get: { viewModel.draft.endDate != nil },
            set: { enabled in
                let fallback = viewModel.draft.startDate?.addingTimeInterval(86400) ?? nextDay
                viewModel.draft.endDate = enabled ? (viewModel.draft.endDate ?? fallback) : nil
            }
        )
    }
    
    private var scheduledTimeEnabledBinding: Binding<Bool> {
        Binding(
            get: { viewModel.draft.scheduledTime != nil },
            set: { enabled in
                viewModel.draft.scheduledTime = enabled ? (viewModel.draft.scheduledTime ?? defaultScheduledTime) : nil
            }
        )
    }
    
    private var defaultScheduledTime: Date {
        Calendar.current.date(
            bySettingHour: 9,
            minute: 0,
            second: 0,
            of: Date()
        ) ?? Date()
    }
    
    private var defaultEndDate: Date {
        viewModel.draft.endDate ?? (viewModel.draft.startDate?.addingTimeInterval(86400) ?? nextDay)
    }
    
    private var nextDay: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date().addingTimeInterval(86400)
    }
    
    private func nonOptionalDateBinding(
        _ keyPath: WritableKeyPath<HabitFormDraft, Date?>,
        defaultValue: Date = Date()
    ) -> Binding<Date> {
        Binding(
            get: { viewModel.draft[keyPath: keyPath] ?? defaultValue },
            set: { viewModel.draft[keyPath: keyPath] = $0 }
        )
    }
    
    private func binding<T>(_ keyPath: WritableKeyPath<HabitFormDraft, T>) -> Binding<T> {
        Binding(
            get: { viewModel.draft[keyPath: keyPath] },
            set: { viewModel.draft[keyPath: keyPath] = $0 }
        )
    }
}

private struct WeekdayChipGrid: View {
    let selectedDays: Set<HabitWeekday>
    let toggle: (HabitWeekday) -> Void
    
    private let columns: [GridItem] = Array(repeating: .init(.flexible(), spacing: 8), count: 4)
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(HabitWeekday.allCases) { day in
                Button {
                    toggle(day)
                } label: {
                    Text(day.shortLabel)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(selectedDays.contains(day) ? Color.accentColor.opacity(0.2) : Color.clear)
                        )
                        .overlay(
                            Capsule()
                                .stroke(selectedDays.contains(day) ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    AddNewHabitView()
        .environment(\.injected, .previewAuthenticated)
}
