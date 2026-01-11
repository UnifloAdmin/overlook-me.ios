//
//  Auth0WebView.swift
//  overlook me
//
//  Created by Naresh Chandra on 1/8/26.
//

import SwiftUI
import AuthenticationServices
import CryptoKit
import UIKit

/// Auth0 login surface that relies on `ASWebAuthenticationSession`
/// to satisfy Google/Apple secure browser requirements.
struct Auth0WebView: UIViewControllerRepresentable {
    let onSuccess: (String, String, String?) -> Void // accessToken, idToken, refreshToken
    let onError: (Error) -> Void
    
    private let codeVerifier: String
    private let codeChallenge: String
    private let state: String
    
    init(
        onSuccess: @escaping (String, String, String?) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        self.onSuccess = onSuccess
        self.onError = onError
        
        // Generate PKCE parameters
        self.codeVerifier = Self.generateCodeVerifier()
        self.codeChallenge = Self.generateCodeChallenge(from: codeVerifier)
        self.state = UUID().uuidString
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            codeVerifier: codeVerifier,
            codeChallenge: codeChallenge,
            state: state,
            onSuccess: onSuccess,
            onError: onError
        )
    }
    
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = AuthSessionViewController()
        controller.coordinator = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    
    // MARK: - PKCE Helpers
    
    private static func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    private static func generateCodeChallenge(from verifier: String) -> String {
        guard let data = verifier.data(using: .utf8) else {
            return verifier
        }
        let hash = SHA256.hash(data: data)
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, ASWebAuthenticationPresentationContextProviding {
        private let codeVerifier: String
        private let codeChallenge: String
        private let state: String
        private let onSuccess: (String, String, String?) -> Void
        private let onError: (Error) -> Void
        private let callbackScheme: String
        
        private var authSession: ASWebAuthenticationSession?
        private var didStartSession = false
        private weak var presentingViewController: UIViewController?
        
        init(
            codeVerifier: String,
            codeChallenge: String,
            state: String,
            onSuccess: @escaping (String, String, String?) -> Void,
            onError: @escaping (Error) -> Void
        ) {
            self.codeVerifier = codeVerifier
            self.codeChallenge = codeChallenge
            self.state = state
            self.onSuccess = onSuccess
            self.onError = onError
            self.callbackScheme = URLComponents(string: Auth0Config.callbackURL)?.scheme ?? "overlookme"
        }
        
        func startAuthentication(presentingViewController: UIViewController) {
            guard !didStartSession else { return }
            didStartSession = true
            self.presentingViewController = presentingViewController
            
            guard let authURL = buildAuthorizationURL() else {
                onError(WebViewError.invalidAuthURL)
                return
            }
            
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: callbackScheme
            ) { [weak self] callbackURL, error in
                guard let self else { return }
                
                if let error {
                    self.onError(error)
                    return
                }
                
                guard let callbackURL else {
                    self.onError(WebViewError.invalidCallback)
                    return
                }
                
                self.handleCallback(url: callbackURL)
            }
            
            session.presentationContextProvider = self
            if #available(iOS 13.0, *) {
                session.prefersEphemeralWebBrowserSession = true
            }
            
            if !session.start() {
                onError(WebViewError.sessionFailedToStart)
            }
            
            authSession = session
        }
        
        func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
            if let window = presentingViewController?.view.window {
                return window
            }
            
            let scenes = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
            for scene in scenes {
                if let window = scene.windows.first(where: { $0.isKeyWindow }) {
                    return window
                }
            }
            
            return ASPresentationAnchor()
        }
        
        private func buildAuthorizationURL() -> URL? {
            var components = URLComponents(string: "https://\(Auth0Config.domain)/authorize")
            components?.queryItems = [
                URLQueryItem(name: "client_id", value: Auth0Config.clientId),
                URLQueryItem(name: "response_type", value: "code"),
                URLQueryItem(name: "redirect_uri", value: Auth0Config.callbackURL),
                URLQueryItem(name: "scope", value: Auth0Config.scope),
                URLQueryItem(name: "state", value: state),
                URLQueryItem(name: "code_challenge", value: codeChallenge),
                URLQueryItem(name: "code_challenge_method", value: "S256")
            ]
            return components?.url
        }
        
        private func handleCallback(url: URL) {
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let queryItems = components.queryItems else {
                onError(WebViewError.invalidCallback)
                return
            }
            
            if let error = queryItems.first(where: { $0.name == "error" })?.value {
                let errorDescription = queryItems.first(where: { $0.name == "error_description" })?.value ?? "Unknown error"
                onError(WebViewError.auth0Error(error: error, description: errorDescription))
                return
            }
            
            guard let code = queryItems.first(where: { $0.name == "code" })?.value else {
                onError(WebViewError.invalidCallback)
                return
            }
            
            guard let returnedState = queryItems.first(where: { $0.name == "state" })?.value,
                  returnedState == state else {
                onError(WebViewError.invalidCallback)
                return
            }
            
            Task {
                do {
                    let tokens = try await exchangeCodeForTokens(code: code)
                    await MainActor.run {
                        onSuccess(tokens.accessToken, tokens.idToken, tokens.refreshToken)
                    }
                } catch {
                    await MainActor.run {
                        onError(error)
                    }
                }
            }
        }
        
        private func exchangeCodeForTokens(code: String) async throws -> TokenResponse {
            let tokenURL = URL(string: "https://\(Auth0Config.domain)/oauth/token")!
            var request = URLRequest(url: tokenURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body: [String: Any] = [
                "grant_type": "authorization_code",
                "client_id": Auth0Config.clientId,
                "code": code,
                "redirect_uri": Auth0Config.callbackURL,
                "code_verifier": codeVerifier
            ]
            
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw WebViewError.tokenExchangeFailed
            }
            
            return try JSONDecoder().decode(TokenResponse.self, from: data)
        }
    }
}

private final class AuthSessionViewController: UIViewController {
    var coordinator: Auth0WebView.Coordinator?
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        coordinator?.startAuthentication(presentingViewController: self)
    }
}

// MARK: - Token Response

private struct TokenResponse: Codable {
    let accessToken: String
    let idToken: String
    let refreshToken: String?
    let expiresIn: Int
    let tokenType: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case idToken = "id_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}

// MARK: - Errors

enum WebViewError: LocalizedError {
    case invalidAuthURL
    case invalidCallback
    case tokenExchangeFailed
    case auth0Error(error: String, description: String)
    case sessionFailedToStart
    
    var errorDescription: String? {
        switch self {
        case .invalidAuthURL:
            return "Could not build authorization URL"
        case .invalidCallback:
            return "Invalid authorization callback"
        case .tokenExchangeFailed:
            return "Failed to exchange code for tokens"
        case .auth0Error(let error, let description):
            return "Auth0 Error: \(error) - \(description)"
        case .sessionFailedToStart:
            return "Unable to start secure browser session"
        }
    }
}
