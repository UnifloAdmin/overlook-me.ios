

import Foundation

/// Protocol defining authentication operations
protocol AuthRepository {
    func loginWithEmail(email: String, password: String) async throws -> CAMAAuthResponse
    func register(email: String, password: String, confirmPassword: String, firstName: String, lastName: String) async throws -> CAMAAuthResponse
    func verifyTwoFactor(userId: String, code: String) async throws -> CAMAAuthResponse
    func forgotPassword(email: String) async throws
    func refreshToken(accessToken: String, refreshToken: String) async throws -> CAMAAuthResponse
    func logout(accessToken: String) async throws
    func getEmailStatus(accessToken: String) async throws -> EmailStatusResponse
    func getTwoFactorStatus(accessToken: String) async throws -> TwoFactorStatusResponse
    func resendVerificationEmail(accessToken: String) async throws
    // 2FA management
    func setupTwoFactor(accessToken: String) async throws -> TwoFactorSetupResponse
    func enableTwoFactor(accessToken: String, code: String, deviceName: String, authenticatorApp: String, platform: String) async throws -> TwoFactorEnableResponse
    func disableTwoFactor(accessToken: String, code: String) async throws -> TwoFactorDisableResponse
    func getAuthenticatorDevices(accessToken: String) async throws -> [AuthenticatorDevice]
    func removeAuthenticatorDevice(accessToken: String, deviceId: String) async throws
}

// MARK: - Real Implementation

struct RealAuthRepository: AuthRepository {
    
    func loginWithEmail(email: String, password: String) async throws -> CAMAAuthResponse {
        let body: [String: Any] = ["email": email, "password": password]
        return try await postJSON(url: CAMAConfig.loginURL, body: body)
    }
    
    func register(email: String, password: String, confirmPassword: String, firstName: String, lastName: String) async throws -> CAMAAuthResponse {
        let body: [String: Any] = [
            "email": email,
            "password": password,
            "confirmPassword": confirmPassword,
            "firstName": firstName,
            "lastName": lastName
        ]
        return try await postJSON(url: CAMAConfig.registerURL, body: body)
    }
    
    func verifyTwoFactor(userId: String, code: String) async throws -> CAMAAuthResponse {
        let body: [String: Any] = ["userId": userId, "code": code]
        return try await postJSON(url: CAMAConfig.twoFactorVerifyLoginURL, body: body)
    }
    
    func forgotPassword(email: String) async throws {
        let body: [String: Any] = ["email": email]
        let url = URL(string: CAMAConfig.forgotPasswordURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let http = response as? HTTPURLResponse
            throw AuthError.requestFailed(statusCode: http?.statusCode ?? 0)
        }
    }
    
    func refreshToken(accessToken: String, refreshToken: String) async throws -> CAMAAuthResponse {
        let body: [String: Any] = ["accessToken": accessToken, "refreshToken": refreshToken]
        return try await postJSON(url: CAMAConfig.refreshTokenURL, body: body)
    }
    
    func logout(accessToken: String) async throws {
        let url = URL(string: CAMAConfig.logoutURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        _ = try? await URLSession.shared.data(for: request)
    }
    
    func getEmailStatus(accessToken: String) async throws -> EmailStatusResponse {
        try await getJSON(url: CAMAConfig.emailStatusURL, accessToken: accessToken)
    }
    
    func getTwoFactorStatus(accessToken: String) async throws -> TwoFactorStatusResponse {
        try await getJSON(url: CAMAConfig.twoFactorStatusURL, accessToken: accessToken)
    }
    
    func resendVerificationEmail(accessToken: String) async throws {
        try await postEmpty(url: CAMAConfig.resendVerificationURL, accessToken: accessToken)
    }

    func setupTwoFactor(accessToken: String) async throws -> TwoFactorSetupResponse {
        try await postJSON(url: CAMAConfig.twoFactorSetupURL, body: [:], accessToken: accessToken)
    }

    func enableTwoFactor(accessToken: String, code: String, deviceName: String, authenticatorApp: String, platform: String) async throws -> TwoFactorEnableResponse {
        let body: [String: Any] = [
            "code": code,
            "deviceName": deviceName,
            "authenticatorApp": authenticatorApp,
            "platform": platform
        ]
        return try await postJSON(url: CAMAConfig.twoFactorEnableURL, body: body, accessToken: accessToken)
    }

    func disableTwoFactor(accessToken: String, code: String) async throws -> TwoFactorDisableResponse {
        try await postJSON(url: CAMAConfig.twoFactorDisableURL, body: ["code": code], accessToken: accessToken)
    }

    func getAuthenticatorDevices(accessToken: String) async throws -> [AuthenticatorDevice] {
        try await getJSON(url: CAMAConfig.twoFactorDevicesURL, accessToken: accessToken)
    }

    func removeAuthenticatorDevice(accessToken: String, deviceId: String) async throws {
        let url = "\(CAMAConfig.twoFactorDevicesURL)/\(deviceId)"
        try await deleteRequest(url: url, accessToken: accessToken)
    }

    // MARK: - Helpers

    private func postEmpty(url: String, accessToken: String) async throws {
        let requestURL = URL(string: url)!
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw AuthError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }
    }

    private func deleteRequest(url: String, accessToken: String) async throws {
        let requestURL = URL(string: url)!
        var request = URLRequest(url: requestURL)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw AuthError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }
    }
    
    private func getJSON<T: Decodable>(url: String, accessToken: String) async throws -> T {
        let requestURL = URL(string: url)!
        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw AuthError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    private func postJSON<T: Decodable>(url: String, body: [String: Any], accessToken: String? = nil) async throws -> T {
        let requestURL = URL(string: url)!
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse else {
            throw AuthError.requestFailed(statusCode: 0)
        }
        
        if http.statusCode == 401 {
            // Try to parse error message
            if let errorResponse = try? JSONDecoder().decode(CAMAErrorResponse.self, from: data) {
                throw AuthError.unauthorized(errorResponse.firstError)
            }
            throw AuthError.unauthorized("Invalid credentials")
        }
        
        guard (200...299).contains(http.statusCode) else {
            if let errorResponse = try? JSONDecoder().decode(CAMAErrorResponse.self, from: data) {
                throw AuthError.serverError(errorResponse.firstError)
            }
            throw AuthError.requestFailed(statusCode: http.statusCode)
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - CAMA Response Models

struct CAMAAuthResponse: Codable {
    let accessToken: String?
    let refreshToken: String?
    let expiresAt: String?
    let userId: String?
    let email: String?
    let firstName: String?
    let lastName: String?
    let sessionId: String?
    let requiresTwoFactor: Bool?
    let emailConfirmed: Bool?
    
    var requiresTwoFactorAuth: Bool { requiresTwoFactor ?? false }
    var isEmailConfirmed: Bool { emailConfirmed ?? false }
}

struct CAMAErrorResponse: Codable {
    let errors: [String]?
    
    var firstError: String {
        errors?.first ?? "An unknown error occurred"
    }
}

struct EmailStatusResponse: Codable {
    let emailConfirmed: Bool
}

struct TwoFactorStatusResponse: Codable {
    let twoFactorEnabled: Bool
    let enabledAt: String?
    let recoveryCodesLeft: Int?
}

struct TwoFactorSetupResponse: Codable {
    let sharedKey: String
    let qrCodeUri: String
}

struct TwoFactorEnableResponse: Codable {
    let twoFactorEnabled: Bool
    let recoveryCodes: [String]?
}

struct TwoFactorDisableResponse: Codable {
    let success: Bool
    let error: String?
}

struct AuthenticatorDevice: Codable, Identifiable {
    let id: String
    let deviceName: String?
    let authenticatorApp: String?
    let platform: String?
    let browser: String?
    let os: String?
    let ipAddress: String?
    let registeredAt: String?
    let isActive: Bool?
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case noCredentials
    case refreshFailed
    case unauthorized(String)
    case serverError(String)
    case requestFailed(statusCode: Int)
    case passwordMismatch
    case missingFields
    
    var errorDescription: String? {
        switch self {
        case .noCredentials:
            return "No credentials found. Please sign in."
        case .refreshFailed:
            return "Session expired. Please sign in again."
        case .unauthorized(let message):
            return message
        case .serverError(let message):
            return message
        case .requestFailed(let code):
            return "Request failed (status \(code))"
        case .passwordMismatch:
            return "Passwords do not match"
        case .missingFields:
            return "Please fill in all fields"
        }
    }
}

// MARK: - Stub Implementation

struct StubAuthRepository: AuthRepository {
    func loginWithEmail(email: String, password: String) async throws -> CAMAAuthResponse {
        CAMAAuthResponse(accessToken: "stub", refreshToken: "stub", expiresAt: nil, userId: "stub_id", email: email, firstName: "Test", lastName: "User", sessionId: "stub_session", requiresTwoFactor: false, emailConfirmed: true)
    }
    
    func register(email: String, password: String, confirmPassword: String, firstName: String, lastName: String) async throws -> CAMAAuthResponse {
        CAMAAuthResponse(accessToken: "stub", refreshToken: "stub", expiresAt: nil, userId: "stub_id", email: email, firstName: firstName, lastName: lastName, sessionId: "stub_session", requiresTwoFactor: false, emailConfirmed: false)
    }
    
    func verifyTwoFactor(userId: String, code: String) async throws -> CAMAAuthResponse {
        CAMAAuthResponse(accessToken: "stub", refreshToken: "stub", expiresAt: nil, userId: userId, email: "user@example.com", firstName: "Test", lastName: "User", sessionId: "stub_session", requiresTwoFactor: false, emailConfirmed: true)
    }
    
    func forgotPassword(email: String) async throws {}
    
    func refreshToken(accessToken: String, refreshToken: String) async throws -> CAMAAuthResponse {
        CAMAAuthResponse(accessToken: "stub_new", refreshToken: "stub_new", expiresAt: nil, userId: "stub_id", email: "user@example.com", firstName: "Test", lastName: "User", sessionId: "stub_session", requiresTwoFactor: false, emailConfirmed: true)
    }
    
    func logout(accessToken: String) async throws {}
    func getEmailStatus(accessToken: String) async throws -> EmailStatusResponse { EmailStatusResponse(emailConfirmed: true) }
    func getTwoFactorStatus(accessToken: String) async throws -> TwoFactorStatusResponse { TwoFactorStatusResponse(twoFactorEnabled: true, enabledAt: "2026-01-15T10:00:00Z", recoveryCodesLeft: 8) }
    func resendVerificationEmail(accessToken: String) async throws {}
    func setupTwoFactor(accessToken: String) async throws -> TwoFactorSetupResponse { TwoFactorSetupResponse(sharedKey: "ABCD1234EFGH5678", qrCodeUri: "otpauth://totp/OverlookMe?secret=ABCD1234EFGH5678") }
    func enableTwoFactor(accessToken: String, code: String, deviceName: String, authenticatorApp: String, platform: String) async throws -> TwoFactorEnableResponse { TwoFactorEnableResponse(twoFactorEnabled: true, recoveryCodes: ["ABC-123", "DEF-456", "GHI-789"]) }
    func disableTwoFactor(accessToken: String, code: String) async throws -> TwoFactorDisableResponse { TwoFactorDisableResponse(success: true, error: nil) }
    func getAuthenticatorDevices(accessToken: String) async throws -> [AuthenticatorDevice] { [] }
    func removeAuthenticatorDevice(accessToken: String, deviceId: String) async throws {}
}
