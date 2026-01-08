//
//  AuthRepository.swift
//  overlook me
//
//  Created by Naresh Chandra on 1/8/26.
//

import Foundation
import CryptoKit

/// Protocol defining authentication operations
protocol AuthRepository {
    func login() async throws -> (Credentials, User)
    func logout() async throws
    func renewCredentials() async throws -> Credentials?
    func getUserInfo(accessToken: String) async throws -> User
}

// MARK: - Real Implementation

struct RealAuthRepository: AuthRepository {
    
    func login() async throws -> (Credentials, User) {
        // This will be called after WebView authentication completes
        // Tokens are already stored, just retrieve them
        guard let accessToken = try? KeychainHelper.retrieveString(for: .accessToken),
              let idToken = try? KeychainHelper.retrieveString(for: .idToken) else {
            throw AuthError.noCredentials
        }
        
        let refreshToken = try? KeychainHelper.retrieveString(for: .refreshToken)
        
        // Get user info
        let user = try await getUserInfo(accessToken: accessToken)
        
        let credentials = Credentials(
            accessToken: accessToken,
            idToken: idToken,
            refreshToken: refreshToken,
            expiresIn: Date().addingTimeInterval(3600), // 1 hour
            scope: Auth0Config.scope,
            tokenType: "Bearer"
        )
        
        return (credentials, user)
    }
    
    func logout() async throws {
        // Clear all stored credentials
        try? KeychainHelper.deleteAll()
    }
    
    func renewCredentials() async throws -> Credentials? {
        guard let refreshToken = try? KeychainHelper.retrieveString(for: .refreshToken) else {
            return nil
        }
        
        // Exchange refresh token for new access token
        let tokenURL = URL(string: "https://\(Auth0Config.domain)/oauth/token")!
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "grant_type": "refresh_token",
            "client_id": Auth0Config.clientId,
            "refresh_token": refreshToken
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthError.refreshFailed
        }
        
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        
        // Store new tokens
        try KeychainHelper.save(tokenResponse.accessToken, for: .accessToken)
        if let newRefreshToken = tokenResponse.refreshToken {
            try KeychainHelper.save(newRefreshToken, for: .refreshToken)
        }
        
        return Credentials(
            accessToken: tokenResponse.accessToken,
            idToken: tokenResponse.idToken,
            refreshToken: tokenResponse.refreshToken,
            expiresIn: Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn)),
            scope: tokenResponse.scope,
            tokenType: tokenResponse.tokenType
        )
    }
    
    func getUserInfo(accessToken: String) async throws -> User {
        let userInfoURL = URL(string: "https://\(Auth0Config.domain)/userinfo")!
        var request = URLRequest(url: userInfoURL)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthError.userInfoFailed
        }
        
        let user = try JSONDecoder().decode(User.self, from: data)
        
        // Store user data
        try KeychainHelper.save(data, for: .userData)
        
        return user
    }
    
    // MARK: - Helper: Store tokens from auth callback
    
    func storeTokens(accessToken: String, idToken: String, refreshToken: String?) throws {
        try KeychainHelper.save(accessToken, for: .accessToken)
        try KeychainHelper.save(idToken, for: .idToken)
        if let refreshToken = refreshToken {
            try KeychainHelper.save(refreshToken, for: .refreshToken)
        }
    }
}

// MARK: - Token Response Model

private struct TokenResponse: Codable {
    let accessToken: String
    let idToken: String
    let refreshToken: String?
    let expiresIn: Int
    let tokenType: String
    let scope: String?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case idToken = "id_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
        case scope
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case noCredentials
    case refreshFailed
    case userInfoFailed
    case authorizationFailed
    
    var errorDescription: String? {
        switch self {
        case .noCredentials:
            return "No credentials found"
        case .refreshFailed:
            return "Failed to refresh token"
        case .userInfoFailed:
            return "Failed to get user info"
        case .authorizationFailed:
            return "Authorization failed"
        }
    }
}

// MARK: - Stub Implementation

struct StubAuthRepository: AuthRepository {
    func login() async throws -> (Credentials, User) {
        let credentials = Credentials(
            accessToken: "stub_access_token",
            idToken: "stub_id_token",
            refreshToken: "stub_refresh_token",
            expiresIn: Date().addingTimeInterval(3600),
            scope: "openid profile email",
            tokenType: "Bearer"
        )
        
        let user = User(
            id: "stub_user_id",
            email: "user@example.com",
            name: "Test User",
            picture: nil,
            emailVerified: true
        )
        
        return (credentials, user)
    }
    
    func logout() async throws {
        // Stub implementation
    }
    
    func renewCredentials() async throws -> Credentials? {
        return nil
    }
    
    func getUserInfo(accessToken: String) async throws -> User {
        return User(
            id: "stub_user_id",
            email: "user@example.com",
            name: "Test User",
            picture: nil,
            emailVerified: true
        )
    }
}
