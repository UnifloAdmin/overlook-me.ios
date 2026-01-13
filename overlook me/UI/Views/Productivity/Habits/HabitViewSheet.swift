import SwiftUI

struct HabitViewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.injected) private var container: DIContainer
    let habit: DailyHabitDTO
    let completion: HabitCompletionLogDTO?
    let isPerformingAction: Bool
    let onAction: (HabitAction) -> Void
    
    private let habitAPI = DailyHabitsAPI(client: LoggingAPIClient(base: AppAPIClient.live()))
    @State private var cycleLogs: [HabitCompletionLogDTO] = []
    @State private var isLoadingLogs = false
    @State private var logsErrorMessage: String?
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
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        trackerSection(for: habit)
                        pomodoroSection
                    }
                    .padding(.top, 32)
                    .padding(.bottom, 48)
                }
                .scrollContentBackground(.hidden)
                .background(Color(.systemBackground))
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarBackButtonHidden(true)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Text(habit.name)
                            .font(.headline)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button("Edit") {
                            // Edit action
                        }
                        
                        Button(role: .close) { dismiss() } label: {
                            Image(systemName: "xmark")
                        }
                    }
                }
            }
        }
        .task(id: habit.id) { await loadCycleLogs() }
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
