//
//  DIContainer.swift
//  overlook me
//
//  Created by Naresh Chandra on 1/8/26.
//

import Foundation
import SwiftUI

/// Dependency Injection Container
struct DIContainer {
    let appState: Store<AppState>
    let interactors: Interactors
    
    init(appState: Store<AppState>, interactors: Interactors) {
        self.appState = appState
        self.interactors = interactors
    }
}

// MARK: - Interactors

extension DIContainer {
    struct Interactors {
        let authInteractor: AuthInteractor
        let itemsInteractor: ItemsInteractor
        let habitsInteractor: HabitsInteractor
        let tasksInteractor: TasksInteractor
        
        init(
            authInteractor: AuthInteractor,
            itemsInteractor: ItemsInteractor,
            habitsInteractor: HabitsInteractor,
            tasksInteractor: TasksInteractor
        ) {
            self.authInteractor = authInteractor
            self.itemsInteractor = itemsInteractor
            self.habitsInteractor = habitsInteractor
            self.tasksInteractor = tasksInteractor
        }
        
        static var stub: Self {
            .init(
                authInteractor: StubAuthInteractor(),
                itemsInteractor: StubItemsInteractor(),
                habitsInteractor: StubHabitsInteractor(),
                tasksInteractor: StubTasksInteractor()
            )
        }
    }
}

// MARK: - Repositories

extension DIContainer {
    struct Repositories {
        let authRepository: AuthRepository
        let itemsRepository: ItemsRepository
        let habitsRepository: HabitsRepository
        let tasksRepository: TasksRepository
        
        init(
            authRepository: AuthRepository,
            itemsRepository: ItemsRepository,
            habitsRepository: HabitsRepository,
            tasksRepository: TasksRepository
        ) {
            self.authRepository = authRepository
            self.itemsRepository = itemsRepository
            self.habitsRepository = habitsRepository
            self.tasksRepository = tasksRepository
        }
        
        static var stub: Self {
            .init(
                authRepository: StubAuthRepository(),
                itemsRepository: StubItemsRepository(),
                habitsRepository: StubHabitsRepository(),
                tasksRepository: StubTasksRepository()
            )
        }
    }
}

// MARK: - Environment Key

private struct DIContainerKey: EnvironmentKey {
    static let defaultValue: DIContainer = {
        DIContainer(appState: Store(AppState()), interactors: .stub)
    }()
}

extension EnvironmentValues {
    var injected: DIContainer {
        get { self[DIContainerKey.self] }
        set { self[DIContainerKey.self] = newValue }
    }
}
