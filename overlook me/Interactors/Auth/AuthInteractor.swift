//
//  AuthInteractor.swift
//  overlook me
//
//  Created by Naresh Chandra on 1/8/26.
//

import Foundation

/// Result types for auth operations
struct LoginResult {
    let success: Bool
    let requiresTwoFactor: Bool
    let userId: String?
    let error: String?
}

struct AuthResult {
    let success: Bool
    let error: String?
}

/// Protocol defining authentication business logic
protocol AuthInteractor {
    func checkAuthentication() async
    func loginWithEmail(email: String, password: String) async -> LoginResult
    func signUp(email: String, password: String, confirmPassword: String, firstName: String, lastName: String) async -> AuthResult
    func forgotPassword(email: String) async -> AuthResult
    func verifyTwoFactor(userId: String, code: String) async -> AuthResult
    func logout() async
    func checkEmailStatus() async -> Bool?
    func checkTwoFactorStatus() async -> Bool?
    func resendVerificationEmail() async -> AuthResult
    // 2FA management
    func setupTwoFactor() async -> TwoFactorSetupResult
    func enableTwoFactor(code: String, deviceName: String, authenticatorApp: String, platform: String) async -> TwoFactorEnableResult
    func disableTwoFactor(code: String) async -> AuthResult
    func getFullTwoFactorStatus() async -> TwoFactorStatusInfo?
    func getAuthenticatorDevices() async -> [AuthenticatorDevice]
    func removeAuthenticatorDevice(deviceId: String) async -> AuthResult
}

struct TwoFactorSetupResult {
    let success: Bool
    let sharedKey: String?
    let qrCodeUri: String?
    let error: String?
}

struct TwoFactorEnableResult {
    let success: Bool
    let recoveryCodes: [String]?
    let error: String?
}

struct TwoFactorStatusInfo {
    let enabled: Bool
    let enabledAt: String?
    let recoveryCodesLeft: Int?
}

// MARK: - Real Implementation

@MainActor
struct RealAuthInteractor: AuthInteractor {
    let appState: Store<AppState>
    let repository: AuthRepository
    
    func checkAuthentication() async {
        appState.state.auth.isLoading = true
        
        guard let accessToken = try? KeychainHelper.retrieveString(for: .accessToken),
              let refreshToken = try? KeychainHelper.retrieveString(for: .refreshToken) else {
            appState.state.auth.isAuthenticated = false
            appState.state.auth.user = nil
            appState.state.auth.isLoading = false
            return
        }
        
        do {
            let response = try await repository.refreshToken(accessToken: accessToken, refreshToken: refreshToken)
            handleAuthSuccess(response)
        } catch {
            let isAuthRejection: Bool
            switch error {
            case AuthError.unauthorized, AuthError.refreshFailed:
                isAuthRejection = true
            case AuthError.requestFailed(let code) where code == 401:
                isAuthRejection = true
            default:
                isAuthRejection = false
            }

            if isAuthRejection {
                appState.state.auth.isAuthenticated = false
                appState.state.auth.user = nil
                try? KeychainHelper.deleteAll()
            } else {
                restoreFromCache()
            }
        }
        
        appState.state.auth.isLoading = false
    }
    
    /// Network failed but tokens may still be valid -- restore session from cached user data.
    private func restoreFromCache() {
        guard let userData = try? KeychainHelper.retrieve(for: .userData),
              let user = try? JSONDecoder().decode(User.self, from: userData) else {
            appState.state.auth.isAuthenticated = false
            appState.state.auth.user = nil
            return
        }
        appState.state.auth.isAuthenticated = true
        appState.state.auth.user = user
    }
    
    func loginWithEmail(email: String, password: String) async -> LoginResult {
        appState.state.auth.isLoading = true
        appState.state.auth.error = nil
        
        do {
            let response = try await repository.loginWithEmail(email: email, password: password)
            
            if response.requiresTwoFactorAuth {
                appState.state.auth.isLoading = false
                return LoginResult(success: true, requiresTwoFactor: true, userId: response.userId, error: nil)
            }
            
            handleAuthSuccess(response)
            appState.state.auth.isLoading = false
            return LoginResult(success: true, requiresTwoFactor: false, userId: nil, error: nil)
        } catch {
            appState.state.auth.isLoading = false
            return LoginResult(success: false, requiresTwoFactor: false, userId: nil, error: error.localizedDescription)
        }
    }
    
    func signUp(email: String, password: String, confirmPassword: String, firstName: String, lastName: String) async -> AuthResult {
        appState.state.auth.isLoading = true
        appState.state.auth.error = nil
        
        do {
            let response = try await repository.register(email: email, password: password, confirmPassword: confirmPassword, firstName: firstName, lastName: lastName)
            handleAuthSuccess(response)
            appState.state.auth.isLoading = false
            return AuthResult(success: true, error: nil)
        } catch {
            appState.state.auth.isLoading = false
            return AuthResult(success: false, error: error.localizedDescription)
        }
    }
    
    func forgotPassword(email: String) async -> AuthResult {
        do {
            try await repository.forgotPassword(email: email)
            return AuthResult(success: true, error: nil)
        } catch {
            return AuthResult(success: false, error: error.localizedDescription)
        }
    }
    
    func verifyTwoFactor(userId: String, code: String) async -> AuthResult {
        appState.state.auth.isLoading = true
        
        do {
            let response = try await repository.verifyTwoFactor(userId: userId, code: code)
            handleAuthSuccess(response)
            appState.state.auth.isLoading = false
            return AuthResult(success: true, error: nil)
        } catch {
            appState.state.auth.isLoading = false
            return AuthResult(success: false, error: error.localizedDescription)
        }
    }
    
    func logout() async {
        appState.state.auth.isLoading = true
        
        if let token = try? KeychainHelper.retrieveString(for: .accessToken) {
            try? await repository.logout(accessToken: token)
        }
        
        try? KeychainHelper.deleteAll()
        appState.state.auth.isAuthenticated = false
        appState.state.auth.user = nil
        appState.state.auth.error = nil
        appState.state.auth.isLoading = false
    }
    
    func checkEmailStatus() async -> Bool? {
        guard let token = try? KeychainHelper.retrieveString(for: .accessToken) else { return nil }
        return try? await repository.getEmailStatus(accessToken: token).emailConfirmed
    }
    
    func checkTwoFactorStatus() async -> Bool? {
        guard let token = try? KeychainHelper.retrieveString(for: .accessToken) else { return nil }
        return try? await repository.getTwoFactorStatus(accessToken: token).twoFactorEnabled
    }
    
    func resendVerificationEmail() async -> AuthResult {
        guard let token = try? KeychainHelper.retrieveString(for: .accessToken) else {
            return AuthResult(success: false, error: "Not authenticated")
        }
        do {
            try await repository.resendVerificationEmail(accessToken: token)
            return AuthResult(success: true, error: nil)
        } catch {
            return AuthResult(success: false, error: error.localizedDescription)
        }
    }
    
    func setupTwoFactor() async -> TwoFactorSetupResult {
        guard let token = try? KeychainHelper.retrieveString(for: .accessToken) else {
            return TwoFactorSetupResult(success: false, sharedKey: nil, qrCodeUri: nil, error: "Not authenticated")
        }
        do {
            let response = try await repository.setupTwoFactor(accessToken: token)
            return TwoFactorSetupResult(success: true, sharedKey: response.sharedKey, qrCodeUri: response.qrCodeUri, error: nil)
        } catch {
            return TwoFactorSetupResult(success: false, sharedKey: nil, qrCodeUri: nil, error: error.localizedDescription)
        }
    }

    func enableTwoFactor(code: String, deviceName: String, authenticatorApp: String, platform: String) async -> TwoFactorEnableResult {
        guard let token = try? KeychainHelper.retrieveString(for: .accessToken) else {
            return TwoFactorEnableResult(success: false, recoveryCodes: nil, error: "Not authenticated")
        }
        do {
            let response = try await repository.enableTwoFactor(accessToken: token, code: code, deviceName: deviceName, authenticatorApp: authenticatorApp, platform: platform)
            return TwoFactorEnableResult(success: response.twoFactorEnabled, recoveryCodes: response.recoveryCodes, error: nil)
        } catch {
            return TwoFactorEnableResult(success: false, recoveryCodes: nil, error: error.localizedDescription)
        }
    }

    func disableTwoFactor(code: String) async -> AuthResult {
        guard let token = try? KeychainHelper.retrieveString(for: .accessToken) else {
            return AuthResult(success: false, error: "Not authenticated")
        }
        do {
            let response = try await repository.disableTwoFactor(accessToken: token, code: code)
            return AuthResult(success: response.success, error: response.error)
        } catch {
            return AuthResult(success: false, error: error.localizedDescription)
        }
    }

    func getFullTwoFactorStatus() async -> TwoFactorStatusInfo? {
        guard let token = try? KeychainHelper.retrieveString(for: .accessToken) else { return nil }
        guard let response = try? await repository.getTwoFactorStatus(accessToken: token) else { return nil }
        return TwoFactorStatusInfo(enabled: response.twoFactorEnabled, enabledAt: response.enabledAt, recoveryCodesLeft: response.recoveryCodesLeft)
    }

    func getAuthenticatorDevices() async -> [AuthenticatorDevice] {
        guard let token = try? KeychainHelper.retrieveString(for: .accessToken) else { return [] }
        return (try? await repository.getAuthenticatorDevices(accessToken: token)) ?? []
    }

    func removeAuthenticatorDevice(deviceId: String) async -> AuthResult {
        guard let token = try? KeychainHelper.retrieveString(for: .accessToken) else {
            return AuthResult(success: false, error: "Not authenticated")
        }
        do {
            try await repository.removeAuthenticatorDevice(accessToken: token, deviceId: deviceId)
            return AuthResult(success: true, error: nil)
        } catch {
            return AuthResult(success: false, error: error.localizedDescription)
        }
    }

    // MARK: - Private
    
    private func handleAuthSuccess(_ response: CAMAAuthResponse) {
        guard let accessToken = response.accessToken,
              let refreshToken = response.refreshToken else { return }
        
        // Store tokens
        try? KeychainHelper.save(accessToken, for: .accessToken)
        try? KeychainHelper.save(refreshToken, for: .refreshToken)
        if let sessionId = response.sessionId {
            try? KeychainHelper.save(sessionId, for: .sessionId)
        }
        
        // Build user
        let fullName = [response.firstName, response.lastName]
            .compactMap { $0 }
            .joined(separator: " ")
        
        let user = User(
            id: response.userId ?? "",
            email: response.email ?? "",
            name: fullName.isEmpty ? nil : fullName,
            picture: nil,
            emailVerified: response.isEmailConfirmed
        )
        
        // Store user data
        if let userData = try? JSONEncoder().encode(user) {
            try? KeychainHelper.save(userData, for: .userData)
        }
        
        appState.state.auth.isAuthenticated = true
        appState.state.auth.user = user
        appState.state.auth.error = nil
    }
}

// MARK: - Stub Implementation

struct StubAuthInteractor: AuthInteractor {
    func checkAuthentication() async {}
    func loginWithEmail(email: String, password: String) async -> LoginResult { LoginResult(success: true, requiresTwoFactor: false, userId: nil, error: nil) }
    func signUp(email: String, password: String, confirmPassword: String, firstName: String, lastName: String) async -> AuthResult { AuthResult(success: true, error: nil) }
    func forgotPassword(email: String) async -> AuthResult { AuthResult(success: true, error: nil) }
    func verifyTwoFactor(userId: String, code: String) async -> AuthResult { AuthResult(success: true, error: nil) }
    func logout() async {}
    func checkEmailStatus() async -> Bool? { true }
    func checkTwoFactorStatus() async -> Bool? { true }
    func resendVerificationEmail() async -> AuthResult { AuthResult(success: true, error: nil) }
    func setupTwoFactor() async -> TwoFactorSetupResult { TwoFactorSetupResult(success: true, sharedKey: "STUB1234", qrCodeUri: "otpauth://totp/stub", error: nil) }
    func enableTwoFactor(code: String, deviceName: String, authenticatorApp: String, platform: String) async -> TwoFactorEnableResult { TwoFactorEnableResult(success: true, recoveryCodes: ["ABC-123"], error: nil) }
    func disableTwoFactor(code: String) async -> AuthResult { AuthResult(success: true, error: nil) }
    func getFullTwoFactorStatus() async -> TwoFactorStatusInfo? { TwoFactorStatusInfo(enabled: false, enabledAt: nil, recoveryCodesLeft: nil) }
    func getAuthenticatorDevices() async -> [AuthenticatorDevice] { [] }
    func removeAuthenticatorDevice(deviceId: String) async -> AuthResult { AuthResult(success: true, error: nil) }
}
