import Foundation

protocol HabitsInteractor {
    func loadHabits(for date: Date?) async
}

enum HabitsError: LocalizedError {
    case missingUser
    
    var errorDescription: String? {
        "Unable to load habits without an authenticated user."
    }
}

@MainActor
struct RealHabitsInteractor: HabitsInteractor {
    let appState: Store<AppState>
    let repository: HabitsRepository
    
    func loadHabits(for date: Date? = nil) async {
        appState.state.habits.isLoading = true
        appState.state.habits.error = nil
        
        guard let authUser = appState.state.auth.user else {
            appState.state.habits.habits = []
            appState.state.habits.error = HabitsError.missingUser
            appState.state.habits.isLoading = false
            return
        }
        let userId = authUser.id
        let oauthId = authUser.oauthId.isEmpty ? nil : authUser.oauthId
        
        do {
            let habits = try await repository.fetchHabits(
                userId: userId,
                oauthId: oauthId,
                queryDate: date,
                isActive: true,
                isArchived: false
            )
            appState.state.habits.habits = habits
            appState.state.habits.isLoading = false
        } catch is CancellationError {
            // Ignore cooperative cancellations triggered by view transitions or refresh hand-offs.
            appState.state.habits.isLoading = false
        } catch let urlError as URLError where urlError.code == .cancelled {
            // Treat URLSession-level cancellations the same way to avoid surfacing bogus errors.
            appState.state.habits.isLoading = false
        } catch {
            appState.state.habits.error = error
            appState.state.habits.isLoading = false
        }
    }
}

struct StubHabitsInteractor: HabitsInteractor {
    func loadHabits(for date: Date?) async {}
}

