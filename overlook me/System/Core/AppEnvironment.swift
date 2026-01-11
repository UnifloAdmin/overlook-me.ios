//
//  AppEnvironment.swift
//  overlook me
//
//  Created by Naresh Chandra on 1/8/26.
//

import Foundation
import SwiftData

/// Container for app-level dependencies
struct AppEnvironment {
    let container: DIContainer
}

extension AppEnvironment {
    static func bootstrap(modelContainer: ModelContainer) -> AppEnvironment {
        let appState = Store<AppState>(AppState())
        
        let repositories = configuredRepositories(modelContainer: modelContainer)
        let interactors = configuredInteractors(appState: appState, repositories: repositories)
        
        let diContainer = DIContainer(appState: appState, interactors: interactors)
        
        return AppEnvironment(container: diContainer)
    }
    
    private static func configuredRepositories(modelContainer: ModelContainer) -> DIContainer.Repositories {
        let authRepository = RealAuthRepository()
        let itemsRepository = RealItemsRepository(modelContainer: modelContainer)
        let habitsAPI = DailyHabitsAPI(client: LoggingAPIClient(base: AppAPIClient.live()))
        let habitsRepository = RealHabitsRepository(api: habitsAPI)
        return .init(
            authRepository: authRepository,
            itemsRepository: itemsRepository,
            habitsRepository: habitsRepository
        )
    }
    
    private static func configuredInteractors(
        appState: Store<AppState>,
        repositories: DIContainer.Repositories
    ) -> DIContainer.Interactors {
        let authInteractor = RealAuthInteractor(
            appState: appState,
            repository: repositories.authRepository
        )
        let itemsInteractor = RealItemsInteractor(
            appState: appState,
            repository: repositories.itemsRepository
        )
        let habitsInteractor = RealHabitsInteractor(
            appState: appState,
            repository: repositories.habitsRepository
        )
        return .init(
            authInteractor: authInteractor,
            itemsInteractor: itemsInteractor,
            habitsInteractor: habitsInteractor
        )
    }
}
