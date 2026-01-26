import SwiftUI

private enum HabitLogStatus: String, CaseIterable, Sendable {
    case completed = "Completed"
    case skipped = "Skipped"
    case missed = "Missed"
    
    var color: Color {
        switch self {
        case .completed: return .green
        case .skipped: return .orange
        case .missed: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .completed: return "checkmark.circle.fill"
        case .skipped: return "minus.circle.fill"
        case .missed: return "xmark.circle.fill"
        }
    }
}

struct HabitViewSheet: View {
    private enum Tab: String, CaseIterable {
        case view = "View"
        case history = "History"
    }
    
    private typealias LogStatus = HabitLogStatus
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.injected) private var container: DIContainer
    let habit: DailyHabitDTO
    let completion: HabitCompletionLogDTO?
    let isPerformingAction: Bool
    let onAction: (HabitAction) -> Void
    
    private let habitAPI = DailyHabitsAPI(client: LoggingAPIClient(base: AppAPIClient.live()))
    @State private var selectedTab: Tab = .view
    @State private var cycleLogs: [HabitCompletionLogDTO] = []
    @State private var historyLogs: [HabitCompletionLogEntryDTO] = []
    @State private var expandedLogId: String?
    @State private var isLoadingLogs = false
    @State private var logsErrorMessage: String?
    @State private var isUpdatingLog = false
    @StateObject private var pomodoro: PomodoroTimerController

    init(
        habit: DailyHabitDTO,
        completion: HabitCompletionLogDTO?,
        isPerformingAction: Bool,
        onAction: @escaping (HabitAction) -> Void
    ) {
        self.habit = habit
        self.completion = completion
        self.isPerformingAction = isPerformingAction
        self.onAction = onAction
        _pomodoro = StateObject(wrappedValue: PomodoroTimerController(habitId: habit.id, habitName: habit.name))
    }
    
    private var backendUserId: String? {
        container.appState.state.auth.user?.id
    }

    private var oauthId: String? {
        let value = container.appState.state.auth.user?.oauthId
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            NavigationStack {
                VStack(spacing: 0) {
                    // Tab Picker
                    Picker("", selection: $selectedTab) {
                        ForEach(Tab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    
                    // Tab Content
                    ScrollView(showsIndicators: false) {
                        switch selectedTab {
                        case .view:
                            viewTabContent
                        case .history:
                            historyTabContent
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
                .background(Color(.systemBackground))
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarBackButtonHidden(true)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button("Edit") {
                            // Edit action
                        }
                        
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                        }
                    }
                }
            }
        }
        .task(id: habit.id) { await loadCycleLogs() }
    }
    
    private var viewTabContent: some View {
        VStack(spacing: 24) {
            trackerSection(for: habit)
            pomodoroSection
        }
        .padding(.top, 24)
        .padding(.bottom, 48)
    }
    
    private var historyTabContent: some View {
        VStack(spacing: 12) {
            if isLoadingLogs && historyLogs.isEmpty {
                ProgressView()
                    .padding(.top, 40)
            } else if historyLogs.isEmpty {
                Text("No history available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 40)
            } else {
                ForEach(historyLogs) { log in
                    expandableHistoryRow(for: log)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 48)
    }
    
    private func expandableHistoryRow(for log: HabitCompletionLogEntryDTO) -> some View {
        let isExpanded = expandedLogId == log.id
        let status = logStatus(for: log)
        
        return VStack(spacing: 0) {
            // Header row (always visible)
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    expandedLogId = isExpanded ? nil : log.id
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formatDate(log.date))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        if let notes = log.generalNotes, !notes.isEmpty, !isExpanded {
                            Text(notes)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    statusBadge(status: status)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    Divider()
                    
                    // Status Editor
                    statusEditorSection(for: log, currentStatus: status)
                    
                    // Reason Section
                    if let reason = log.reason {
                        reasonSection(reason: reason)
                    }
                    
                    // Metrics Section
                    if let metrics = log.metrics, !metrics.isEmpty {
                        metricsSection(metrics: metrics)
                    }
                    
                    // Notes Section
                    if let notes = log.generalNotes, !notes.isEmpty {
                        notesSection(notes: notes)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func statusEditorSection(for log: HabitCompletionLogEntryDTO, currentStatus: LogStatus) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Status")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            
            HStack(spacing: 8) {
                ForEach(LogStatus.allCases, id: \.self) { status in
                    statusButton(for: log, status: status, isSelected: currentStatus == status)
                }
            }
        }
    }
    
    private func statusButton(for log: HabitCompletionLogEntryDTO, status: LogStatus, isSelected: Bool) -> some View {
        Button {
            _Concurrency.Task { @MainActor in
                await updateLogStatus(log: log, to: status)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: status.icon)
                    .font(.caption)
                Text(status.rawValue)
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? status.color.opacity(0.2) : Color(.tertiarySystemFill))
            .foregroundStyle(isSelected ? status.color : .secondary)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .disabled(isUpdatingLog)
    }
    
    private func reasonSection(reason: CompletionReasonDTO) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reason")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 6) {
                if !reason.reasonText.isEmpty && reason.reasonText != "No reason provided" {
                    Text(reason.reasonText)
                        .font(.subheadline)
                }
                
                HStack(spacing: 12) {
                    if let trigger = reason.triggerCategory {
                        Label(trigger.capitalized, systemImage: triggerIcon(for: trigger))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    if let sentiment = reason.sentiment {
                        Label(sentiment.capitalized, systemImage: sentimentIcon(for: sentiment))
                            .font(.caption)
                            .foregroundStyle(sentimentColor(for: sentiment))
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(8)
        }
    }
    
    private func metricsSection(metrics: [EffortMetricDTO]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Metrics")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(metrics, id: \.metricType) { metric in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(metric.displayLabel ?? metric.metricType.capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(Int(metric.metricValue)) \(metric.metricUnit)")
                                .font(.subheadline.weight(.medium))
                        }
                        Spacer()
                    }
                    .padding(10)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    private func notesSection(notes: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            
            Text(notes)
                .font(.subheadline)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(8)
        }
    }
    
    private func statusBadge(status: LogStatus) -> some View {
        Text(status.rawValue)
            .font(.caption.weight(.medium))
            .foregroundStyle(status.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(status.color.opacity(0.15))
            .cornerRadius(8)
    }
    
    private func logStatus(for log: HabitCompletionLogEntryDTO) -> LogStatus {
        if log.completed {
            return .completed
        } else if log.wasSkipped == true {
            return .skipped
        } else {
            return .missed
        }
    }
    
    private func triggerIcon(for trigger: String) -> String {
        switch trigger.lowercased() {
        case "stress": return "brain.head.profile"
        case "social": return "person.2.fill"
        case "boredom": return "clock.fill"
        case "tired": return "moon.zzz.fill"
        case "emotional": return "heart.fill"
        case "environmental": return "location.fill"
        case "physical": return "figure.walk"
        case "time": return "calendar.badge.clock"
        default: return "ellipsis.circle.fill"
        }
    }
    
    private func sentimentIcon(for sentiment: String) -> String {
        switch sentiment.lowercased() {
        case "amazing": return "star.fill"
        case "great": return "face.smiling.fill"
        case "good": return "hand.thumbsup.fill"
        case "okay": return "hand.raised.fill"
        case "struggling": return "face.dashed.fill"
        case "rough": return "hand.thumbsdown.fill"
        case "terrible": return "xmark.circle.fill"
        default: return "questionmark.circle"
        }
    }
    
    private func sentimentColor(for sentiment: String) -> Color {
        switch sentiment.lowercased() {
        case "amazing", "great": return .green
        case "good", "okay": return .blue
        case "struggling": return .orange
        case "rough", "terrible": return .red
        default: return .secondary
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let inputFormatter = ISO8601DateFormatter()
        inputFormatter.formatOptions = [.withFullDate]
        
        if let date = inputFormatter.date(from: String(dateString.prefix(10))) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateStyle = .medium
            return outputFormatter.string(from: date)
        }
        return String(dateString.prefix(10))
    }
    
    @MainActor
    private func updateLogStatus(log: HabitCompletionLogEntryDTO, to newStatus: LogStatus) async {
        guard let userId = backendUserId else { return }
        
        isUpdatingLog = true
        defer { isUpdatingLog = false }
        
        let request = LogHabitCompletionRequestDTO(
            habitId: habit.id,
            date: log.date,
            completed: newStatus == .completed,
            value: nil,
            notes: nil,
            wasSkipped: newStatus == .skipped,
            completedAt: newStatus == .completed ? ISO8601DateFormatter().string(from: Date()) : nil,
            metrics: log.metrics,
            reason: log.reason,
            generalNotes: log.generalNotes
        )
        
        do {
            _ = try await habitAPI.logCompletion(
                habitId: habit.id,
                userId: userId,
                completion: request,
                oauthId: oauthId
            )
            // Refresh logs after update
            await loadCycleLogs()
        } catch {
            print("Failed to update log status: \(error)")
        }
    }
    
    @ViewBuilder
    private func trackerSection(for habit: DailyHabitDTO) -> some View {
        if isLoadingLogs && cycleLogs.isEmpty {
            ProgressView()
                .padding(.horizontal, 20)
        } else if let message = logsErrorMessage, cycleLogs.isEmpty {
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
        } else if !cycleLogs.isEmpty {
            HabitCycleTracker(logs: cycleLogs)
                .padding(.horizontal, 20)
        } else {
            EmptyView()
        }
    }
    
    private var pomodoroSection: some View {
        PomodoroCard(controller: pomodoro)
            .padding(.horizontal, 20)
    }

    @MainActor
    private func loadCycleLogs() async {
        // Show any logs already included in the habit payload while we refresh from the logs endpoint.
        cycleLogs = habit.completionLogs ?? []

        guard let userId = backendUserId else { return }

        isLoadingLogs = true
        logsErrorMessage = nil
        defer { isLoadingLogs = false }

        do {
            let entries = try await habitAPI.getCompletionLogs(
                habitId: habit.id,
                userId: userId,
                oauthId: oauthId,
                pageSize: 50
            )
#if DEBUG
            logCompletionLogsResponse(entries)
#endif
            // Store full entries for history tab
            historyLogs = entries.sorted { $0.date > $1.date }
            
            // Map to simplified DTOs for cycle tracker
            cycleLogs = entries.map {
                HabitCompletionLogDTO(
                    date: $0.date,
                    completed: $0.completed,
                    value: nil,
                    notes: $0.generalNotes,
                    completedAt: $0.completedAt,
                    wasSkipped: $0.wasSkipped ?? false
                )
            }
        } catch {
            logsErrorMessage = error.localizedDescription
        }
    }

#if DEBUG
    private func logCompletionLogsResponse(_ entries: [HabitCompletionLogEntryDTO]) {
        let sorted = entries.sorted { $0.date > $1.date }

        print("")
        print("========== DailyHabits Logs ==========")
        print("habit: \(habit.name)")
        print("habitId: \(habit.id)")
        print("count: \(entries.count)")
        print("--------------------------------------")

        for entry in sorted {
            let dateOnly = String(entry.date.prefix(10))
            let status: String
            if entry.completed {
                status = "COMPLETED"
            } else if entry.wasSkipped ?? false {
                status = "SKIPPED"
            } else {
                status = "MISSED"
            }
            print("- \(dateOnly) | \(status) | id=\(shortID(entry.id))")
        }

        // Keep the raw payload available (but visually separated).
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(entries)
            let json = String(decoding: data, as: UTF8.self)
            print("--------------------------------------")
            print("RAW JSON:")
            print(json)
            print("======================================")
            print("")
        } catch {
            print("--------------------------------------")
            print("RAW JSON: (failed to encode)")
            print("======================================")
            print("")
        }
    }

    private func shortID(_ id: String) -> String {
        let prefix = id.prefix(8)
        return "\(prefix)…"
    }
#endif
}

