//
//  AuthInteractor.swift
//  overlook me
//
//  Created by Naresh Chandra on 1/8/26.
//

import Foundation

/// Protocol defining authentication business logic
protocol AuthInteractor {
    func checkAuthentication() async
    func completeLogin(accessToken: String, idToken: String, refreshToken: String?) async
    func logout() async
}

// MARK: - Real Implementation

@MainActor
struct RealAuthInteractor: AuthInteractor {
    let appState: Store<AppState>
    let repository: AuthRepository
    
    func checkAuthentication() async {
        appState.state.auth.isLoading = true
        
        do {
            // Try to get stored credentials
            guard let accessToken = try? KeychainHelper.retrieveString(for: .accessToken) else {
                appState.state.auth.isAuthenticated = false
                appState.state.auth.user = nil
                appState.state.auth.isLoading = false
                return
            }
            
            // Try to get user info
            let user = try await repository.getUserInfo(accessToken: accessToken)
            
            appState.state.auth.isAuthenticated = true
            appState.state.auth.user = user
            appState.state.auth.isLoading = false
        } catch {
            // Credentials might be expired, try to refresh
            do {
                if let credentials = try await repository.renewCredentials() {
                    let user = try await repository.getUserInfo(accessToken: credentials.accessToken)
                    appState.state.auth.isAuthenticated = true
                    appState.state.auth.user = user
                } else {
                    appState.state.auth.isAuthenticated = false
                    appState.state.auth.user = nil
                }
            } catch {
                appState.state.auth.isAuthenticated = false
                appState.state.auth.user = nil
            }
            appState.state.auth.isLoading = false
        }
    }
    
    func completeLogin(accessToken: String, idToken: String, refreshToken: String?) async {
        appState.state.auth.isLoading = true
        appState.state.auth.error = nil
        
        do {
            // Store tokens in Keychain
            try KeychainHelper.save(accessToken, for: .accessToken)
            try KeychainHelper.save(idToken, for: .idToken)
            if let refreshToken = refreshToken {
                try KeychainHelper.save(refreshToken, for: .refreshToken)
            }
            
            // Get user info
            let user = try await repository.getUserInfo(accessToken: accessToken)
            
            appState.state.auth.isAuthenticated = true
            appState.state.auth.user = user
            appState.state.auth.error = nil
        } catch {
            appState.state.auth.isAuthenticated = false
            appState.state.auth.error = error
        }
        
        appState.state.auth.isLoading = false
    }
    
    func logout() async {
        appState.state.auth.isLoading = true
        
        do {
            try await repository.logout()
            
            appState.state.auth.isAuthenticated = false
            appState.state.auth.user = nil
            appState.state.auth.error = nil
        } catch {
            appState.state.auth.error = error
        }
        
        appState.state.auth.isLoading = false
    }
}

// MARK: - Stub Implementation

struct StubAuthInteractor: AuthInteractor {
    func checkAuthentication() async {
        // Stub implementation
    }
    
    func completeLogin(accessToken: String, idToken: String, refreshToken: String?) async {
        // Stub implementation
    }
    
    func logout() async {
        // Stub implementation
    }
}
