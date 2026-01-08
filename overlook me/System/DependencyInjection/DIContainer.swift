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
        
        init(authInteractor: AuthInteractor, itemsInteractor: ItemsInteractor) {
            self.authInteractor = authInteractor
            self.itemsInteractor = itemsInteractor
        }
        
        static var stub: Self {
            .init(
                authInteractor: StubAuthInteractor(),
                itemsInteractor: StubItemsInteractor()
            )
        }
    }
}

// MARK: - Repositories

extension DIContainer {
    struct Repositories {
        let authRepository: AuthRepository
        let itemsRepository: ItemsRepository
        
        init(authRepository: AuthRepository, itemsRepository: ItemsRepository) {
            self.authRepository = authRepository
            self.itemsRepository = itemsRepository
        }
        
        static var stub: Self {
            .init(
                authRepository: StubAuthRepository(),
                itemsRepository: StubItemsRepository()
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
