import SwiftUI

struct AddNewTask: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.injected) private var container
    
    // Task properties
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var priority: TaskPriority = .medium
    
    // Dates and time
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = Date()
    
    // Duration
    @State private var hasEstimatedDuration: Bool = false
    @State private var estimatedDurationMinutes: Int = 30
    
    // Organization
    @State private var category: String = ""
    @State private var project: String = ""
    @State private var tags: String = ""
    
    // Appearance
    @State private var selectedColor: String = "#007AFF"
    
    // Location
    @State private var hasLocation: Bool = false
    @State private var location: String = ""
    
    // Advanced
    @State private var isProMode: Bool = false
    @State private var isFuture: Bool = false
    @State private var showAdvancedOptions: Bool = false
    
    // UI State
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?
    
    // Predefined colors
    private let colorOptions: [String] = [
        "#007AFF", "#FF9500", "#FF3B30", "#34C759",
        "#5856D6", "#FF2D55", "#5AC8FA", "#FFCC00"
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                // Required Info Section
                Section("Required") {
                    TextField("Task title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    Toggle("Due Date", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Due", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Priority")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 8) {
                            ForEach([TaskPriority.low, .medium, .high, .critical], id: \.self) { p in
                                Button {
                                    priority = p
                                } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: priorityIcon(p))
                                            .font(.title3)
                                        Text(priorityLabel(p))
                                            .font(.caption2)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.8)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 60)
                                    .background {
                                        if priority == p {
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(priorityColor(p).opacity(0.15))
                                                .overlay {
                                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                        .fill(.ultraThinMaterial)
                                                }
                                        } else {
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(.ultraThinMaterial)
                                        }
                                    }
                                    .foregroundStyle(priority == p ? priorityColor(p) : .secondary)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(priority == p ? priorityColor(p) : Color.secondary.opacity(0.2), lineWidth: priority == p ? 2 : 1)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                }
                
                Section {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showAdvancedOptions.toggle()
                        }
                    } label: {
                        HStack {
                            Text("Advanced Options")
                            Spacer()
                            Image(systemName: "chevron.down")
                                .rotationEffect(.degrees(showAdvancedOptions ? 180 : 0))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if showAdvancedOptions {
                        Text("Status")
                            .font(.headline)
                        Text("Defaults to Pending when creating a task.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text("Duration")
                            .font(.headline)
                        Toggle("Estimated Duration", isOn: $hasEstimatedDuration)
                        
                        if hasEstimatedDuration {
                            Stepper(value: $estimatedDurationMinutes, in: 5...480, step: 5) {
                                HStack {
                                    Text("Duration")
                                    Spacer()
                                    Text("\(estimatedDurationMinutes) min")
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                            }
                        }
                        
                        Text("Organization")
                            .font(.headline)
                        TextField("Category", text: $category)
                        TextField("Project", text: $project)
                        TextField("Tags (comma separated)", text: $tags)
                        
                        Text("Color")
                            .font(.headline)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(colorOptions, id: \.self) { color in
                                    Button {
                                        selectedColor = color
                                    } label: {
                                        ZStack {
                                            Circle()
                                                .fill(Color(hex: color))
                                                .frame(width: 40, height: 40)
                                            
                                            if selectedColor == color {
                                                Circle()
                                                    .strokeBorder(.white, lineWidth: 3)
                                                    .frame(width: 40, height: 40)
                                                
                                                Image(systemName: "checkmark")
                                                    .font(.caption.bold())
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        
                        Text("Location")
                            .font(.headline)
                        Toggle("Add Location", isOn: $hasLocation)
                        
                        if hasLocation {
                            TextField("Location name", text: $location)
                        }
                        
                        Text("Advanced")
                            .font(.headline)
                        Toggle("Pro Mode", systemImage: "star.fill", isOn: $isProMode)
                        Toggle("Future Task", systemImage: "calendar.badge.clock", isOn: $isFuture)
                    }
                }
                
                // Error message
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Create Task")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .accessibilityLabel("Close")
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        _Concurrency.Task {
                            await saveTask()
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Create")
                                .bold()
                        }
                    }
                    .disabled(title.isEmpty || description.isEmpty || isSaving)
                }
            }
        }
    }
    
    // MARK: - Save Task
    
    private func saveTask() async {
        isSaving = true
        errorMessage = nil
        
        let now = Date()
        let scheduledTimeString: String? = formatTime(now)
        
        await container.interactors.tasksInteractor.createTask(
            title: title,
            description: description,
            descriptionFormat: "plain",
            status: .pending,
            priority: priority,
            scheduledDate: now,
            scheduledTime: scheduledTimeString,
            dueDateTime: hasDueDate ? dueDate : nil,
            estimatedDurationMinutes: hasEstimatedDuration ? estimatedDurationMinutes : nil,
            category: category.isEmpty ? nil : category,
            project: project.isEmpty ? nil : project,
            tags: tags.isEmpty ? nil : tags,
            color: selectedColor,
            location: hasLocation ? location : nil,
            latitude: nil,
            longitude: nil,
            isProModeEnabled: isProMode,
            isFuture: isFuture
        )
        
        isSaving = false
        
        if container.appState.state.tasks.error == nil {
            dismiss()
        } else {
            errorMessage = container.appState.state.tasks.error?.localizedDescription
        }
    }
    
    // MARK: - Helper Functions
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
    
    private func priorityIcon(_ p: TaskPriority) -> String {
        switch p {
        case .critical: return "exclamationmark.3"
        case .high: return "exclamationmark.2"
        case .medium: return "minus"
        case .low: return "arrow.down"
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
