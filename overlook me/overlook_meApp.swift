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
    
    private var isAuthenticated: Bool {
        container.appState.state.auth.isAuthenticated
    }
    
    var body: some View {
        Group {
            if isAuthenticated {
                HomeView()
            } else {
                LandingView()
            }
        }
        .animation(.easeInOut, value: isAuthenticated)
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @Environment(\.injected) private var container: DIContainer
    
    private var user: User? {
        container.appState.state.auth.user
    }
    
    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Label("Items", systemImage: "list.bullet")
                }
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
        }
    }
}

// MARK: - Profile View

struct ProfileView: View {
    @Environment(\.injected) private var container: DIContainer
    
    private var state: AppState { container.appState.state }
    private var interactor: AuthInteractor { container.interactors.authInteractor }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                if let user = state.auth.user {
                    // User avatar
                    if let pictureURL = user.picture, let url = URL(string: pictureURL) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            defaultAvatar
                        }
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.blue, lineWidth: 3))
                    } else {
                        defaultAvatar
                    }
                    
                    // User info
                    VStack(spacing: 8) {
                        if let name = user.name {
                            Text(name)
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        
                        Text(user.email)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if user.emailVerified {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.shield.fill")
                                    .foregroundColor(.green)
                                Text("Verified")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Logout button
                    Button(action: logout) {
                        if state.auth.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Sign Out")
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.horizontal, 40)
                }
            }
            .padding()
            .navigationTitle("Profile")
        }
    }
    
    private var defaultAvatar: some View {
        Image(systemName: "person.circle.fill")
            .resizable()
            .frame(width: 100, height: 100)
            .foregroundColor(.blue)
    }
    
    private func logout() {
        Task {
            await interactor.logout()
        }
    }
}

#Preview("Authenticated") {
    RootView()
        .environment(\.injected, .previewAuthenticated)
}

#Preview("Not Authenticated") {
    RootView()
        .environment(\.injected, .preview)
}

// MARK: - Preview Helpers

extension DIContainer {
    static var previewAuthenticated: Self {
        let appState = Store<AppState>(AppState())
        appState.state.auth.isAuthenticated = true
        appState.state.auth.user = User(
            id: "preview_user",
            email: "user@example.com",
            name: "Preview User",
            picture: nil,
            emailVerified: true
        )
        return DIContainer(appState: appState, interactors: .stub)
    }
}
