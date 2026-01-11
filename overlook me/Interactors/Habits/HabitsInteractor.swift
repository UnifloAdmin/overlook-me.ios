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
        let oauthId = authUser.oauthId
        let backendUserId = oauthId.isEmpty ? authUser.id : oauthId
        
        do {
            let habits = try await repository.fetchHabits(
                userId: backendUserId,
                oauthId: oauthId,
                queryDate: date,
                isActive: true,
                isArchived: false
            )
            appState.state.habits.habits = habits
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

