//
//  overlook_meApp.swift
//  overlook me
//
//  Created by Naresh Chandra on 1/8/26.
//

import SwiftUI
import SwiftData
import LocalAuthentication

@main
struct overlook_meApp: App {
    private let environment: AppEnvironment
    
    init() {
        // Print API configuration on app launch for debugging
        APIConfiguration.printConfiguration()
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
    @State private var isBiometricUnlocked = false
    @State private var isBiometricAvailable = true
    @State private var biometricErrorMessage: String?
    @AppStorage("isFaceIdDisabled") private var isFaceIdDisabled = false
    
    var body: some View {
        ZStack {
            RootContentView(appState: container.appState)
                .blur(radius: isBiometricUnlocked ? 0 : 8)
                .disabled(!isBiometricUnlocked)
            
            if !isBiometricUnlocked {
                BiometricLockView(
                    errorMessage: biometricErrorMessage,
                    isBiometricAvailable: isBiometricAvailable,
                    onRetry: authenticateOnLaunch
                )
            }
        }
        .task {
            authenticateOnLaunch()
        }
        .onChange(of: isFaceIdDisabled) { _, newValue in
            if newValue {
                isBiometricUnlocked = true
                biometricErrorMessage = nil
            } else {
                isBiometricUnlocked = false
                authenticateOnLaunch()
            }
        }
    }
    
    private func authenticateOnLaunch() {
        guard !isBiometricUnlocked else { return }
        guard !isFaceIdDisabled else {
            isBiometricUnlocked = true
            biometricErrorMessage = nil
            return
        }
        
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Unlock to access your workspace."
            ) { success, evaluationError in
                DispatchQueue.main.async {
                    if success {
                        isBiometricUnlocked = true
                        biometricErrorMessage = nil
                    } else {
                        biometricErrorMessage = evaluationError?.localizedDescription ?? "Face ID failed. Please try again."
                    }
                }
            }
        } else {
            isBiometricAvailable = false
            isBiometricUnlocked = true
            biometricErrorMessage = nil
        }
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

private struct BiometricLockView: View {
    let errorMessage: String?
    let isBiometricAvailable: Bool
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "faceid")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.secondary)
            
            Text(isBiometricAvailable ? "Unlock with Face ID" : "Biometric unlock unavailable")
                .font(.headline)
            
            if let errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if isBiometricAvailable {
                Button("Try Face ID Again", action: onRetry)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
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
