//
//  overlook_meApp.swift
//  overlook me
//
//  Created by Naresh Chandra on 1/8/26.
//

import SwiftUI
import SwiftData

@main
struct overlook_meApp: App {
    private let environment: AppEnvironment
    
    init() {
        self.environment = Self.bootstrap()
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.injected, environment.container)
                .task {
                    // Check authentication on app launch
                    await environment.container.interactors.authInteractor.checkAuthentication()
                }
        }
    }
    
    private static func bootstrap() -> AppEnvironment {
        let modelContainer = createModelContainer()
        return AppEnvironment.bootstrap(modelContainer: modelContainer)
    }
    
    private static func createModelContainer() -> ModelContainer {
        let schema = Schema([Item.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
}

// MARK: - Root View

struct RootView: View {
    @Environment(\.injected) private var container: DIContainer
    
    var body: some View {
        RootContentView(appState: container.appState)
    }
}

private struct RootContentView: View {
    @ObservedObject var appState: Store<AppState>
    
    var body: some View {
        Group {
            if appState.state.auth.isAuthenticated {
                MainContainerView()
            } else {
                LandingView()
            }
        }
        .animation(.easeInOut, value: appState.state.auth.isAuthenticated)
    }
}

// MARK: - Preview Helpers

extension DIContainer {
    static var previewAuthenticated: Self {
        let appState = Store<AppState>(AppState())
        appState.state.auth.isAuthenticated = true
        appState.state.auth.user = User(
            id: "preview_user",
            oauthId: "auth0|preview",
            email: "user@example.com",
            name: "Preview User",
            picture: nil,
            emailVerified: true
        )
        return DIContainer(appState: appState, interactors: .stub)
    }
}
