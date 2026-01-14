import SwiftUI

struct ViewHabitsView: View {
    @Environment(\.injected) private var container: DIContainer
    @State private var hasLoadedOnce = false
    @State private var visibleHabits: [DailyHabitDTO] = []
    
    private var habitsState: AppState.HabitsState { container.appState.state.habits }
    private var interactor: HabitsInteractor { container.interactors.habitsInteractor }
    private var isAuthenticated: Bool { container.appState.state.auth.user != nil }
    
    var body: some View {
        NavigationStack {
            content
                .navigationTitle("View Habits")
                .task { await loadHabitsIfNeeded() }
                .refreshable { await loadHabitsIfNeeded(force: true) }
        }
    }
    
    @ViewBuilder
    private var content: some View {
        if habitsState.isLoading && visibleHabits.isEmpty {
            loadingView
        } else if let error = habitsState.error {
            errorView(error)
        } else if visibleHabits.isEmpty {
            emptyState
        } else {
            List {
                Section("Active Habits") {
                    ForEach(visibleHabits) { habit in
                        ViewHabitsRow(habit: habit)
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading your habits…")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding()
    }
    
    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundColor(.orange)
            Text("Unable to load habits")
                .font(.headline)
            Text(error.localizedDescription)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
_Concurrency.Task { await loadHabitsIfNeeded(force: true) }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.grid.2x2")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("No habits to show")
                .font(.headline)
            Text("Create a habit to see it listed here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private func loadHabitsIfNeeded(force: Bool = false) async {
        guard isAuthenticated else { return }
        if !force && hasLoadedOnce { return }
        hasLoadedOnce = true
        await interactor.loadHabits(for: nil)
        await MainActor.run {
            visibleHabits = container.appState.state.habits.habits
        }
    }
}

private struct ViewHabitsRow: View {
    let habit: DailyHabitDTO
    
    private var isPositiveHabit: Bool { habit.isPositive ?? true }
    private var frequencyLabel: String {
        (habit.frequency ?? "daily")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(habit.name)
                    .font(.headline)
                if let priority = habit.priority?.capitalized, !priority.isEmpty {
                    Text(priority)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            
            if let description = habit.description, !description.isEmpty {
                Text(description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            
            HStack(spacing: 12) {
                Label(frequencyLabel, systemImage: "repeat")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if let streak = habit.currentStreak, streak > 0 {
                    Label("\(streak) day streak", systemImage: "flame.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                
                if let completions = habit.totalCompletions, completions > 0 {
                    Label("\(completions) wins", systemImage: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            
            Label(isPositiveHabit ? "Positive habit" : "Habit to reduce",
                  systemImage: isPositiveHabit ? "arrow.up" : "arrow.down")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(isPositiveHabit ? Color.green : Color.red)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    ViewHabitsView()
        .environment(\.injected, .previewAuthenticated)
}
