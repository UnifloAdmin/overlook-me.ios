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
                .background(Color.white.ignoresSafeArea())
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
            emptyView
        } else {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(visibleHabits) { habit in
                        ViewHabitsRow(habit: habit)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading your habits…")
                .font(.system(size: 13))
                .foregroundStyle(Color(red: 0.631, green: 0.631, blue: 0.671))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundStyle(Color.orange)
            Text("Unable to load habits")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(red: 0.035, green: 0.035, blue: 0.043))
            Text(error.localizedDescription)
                .font(.system(size: 13))
                .foregroundStyle(Color(red: 0.443, green: 0.443, blue: 0.482))
                .multilineTextAlignment(.center)
            Button {
                _Concurrency.Task { await loadHabitsIfNeeded(force: true) }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Color(red: 0.035, green: 0.035, blue: 0.043), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.grid.2x2")
                .font(.system(size: 36))
                .foregroundStyle(Color(red: 0.631, green: 0.631, blue: 0.671))
            Text("No habits to show")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(red: 0.035, green: 0.035, blue: 0.043))
            Text("Create a habit to see it listed here.")
                .font(.system(size: 13))
                .foregroundStyle(Color(red: 0.443, green: 0.443, blue: 0.482))
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

// MARK: - Row

private struct ViewHabitsRow: View {
    let habit: DailyHabitDTO

    private let kalPrimary  = Color(red: 0.035, green: 0.035, blue: 0.043)
    private let kalMuted    = Color(red: 0.443, green: 0.443, blue: 0.482)
    private let kalTertiary = Color(red: 0.631, green: 0.631, blue: 0.671)
    private let kalBorder   = Color(red: 0.941, green: 0.941, blue: 0.941)
    private let kalDone     = Color(red: 0.086, green: 0.639, blue: 0.290)
    private let kalDoneBg   = Color(red: 0.863, green: 0.988, blue: 0.906)
    private let kalFail     = Color(red: 0.863, green: 0.149, blue: 0.149)
    private let kalFailBg   = Color(red: 0.996, green: 0.886, blue: 0.886)

    private var isPositive: Bool { habit.isPositive ?? true }
    private var frequencyLabel: String {
        (habit.frequency ?? "daily")
            .replacingOccurrences(of: "_", with: " ")
            .uppercased()
    }

    var body: some View {
        HStack(spacing: 12) {
            typeIndicator
            info
            Spacer(minLength: 0)
            stats
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(kalBorder, lineWidth: 1)
        )
    }

    private var typeIndicator: some View {
        Image(systemName: isPositive ? "arrow.up" : "arrow.down")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(isPositive ? kalDone : kalFail)
            .frame(width: 28, height: 28)
            .background(Circle().fill(isPositive ? kalDoneBg : kalFailBg))
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(habit.name)
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(-0.28)
                    .foregroundStyle(kalPrimary)
                    .lineLimit(1)

                if let priority = habit.priority?.uppercased(), !priority.isEmpty {
                    Text(priority)
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.54)
                        .foregroundStyle(kalTertiary)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color(red: 0.957, green: 0.957, blue: 0.961), in: Capsule())
                }
            }

            HStack(spacing: 5) {
                Text(frequencyLabel)
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.54)
                    .foregroundStyle(kalTertiary)

                if let cat = habit.category, !cat.isEmpty {
                    Text("·").foregroundStyle(kalTertiary)
                    Text(cat.uppercased())
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.54)
                        .foregroundStyle(kalTertiary)
                }
            }

            if let description = habit.description, !description.isEmpty {
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(kalMuted)
                    .lineLimit(2)
            }
        }
    }

    private var stats: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if let streak = habit.currentStreak, streak > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill").font(.system(size: 9))
                    Text("\(streak)")
                        .font(.system(size: 13, weight: .bold))
                        .tracking(-0.12)
                }
                .foregroundStyle(Color.orange)
            }
            if let completions = habit.totalCompletions, completions > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 9))
                    Text("\(completions)")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(-0.11)
                }
                .foregroundStyle(kalDone)
            }
        }
    }
}

#Preview {
    ViewHabitsView()
        .environment(\.injected, .previewAuthenticated)
}
