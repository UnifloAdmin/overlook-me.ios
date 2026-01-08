//
//  Auth0WebView.swift
//  overlook me
//
//  Created by Naresh Chandra on 1/8/26.
//

import SwiftUI
import WebKit
import CryptoKit

/// In-app WebView for Auth0 authentication
struct Auth0WebView: UIViewRepresentable {
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
            state: state,
            onSuccess: onSuccess,
            onError: onError
        )
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        
        // Build Auth0 authorization URL
        var components = URLComponents(string: "https://\(Auth0Config.domain)/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: Auth0Config.clientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: Auth0Config.callbackURL),
            URLQueryItem(name: "scope", value: Auth0Config.scope),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        
        if let url = components.url {
            webView.load(URLRequest(url: url))
        }
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
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
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let codeVerifier: String
        let state: String
        let onSuccess: (String, String, String?) -> Void
        let onError: (Error) -> Void
        
        init(
            codeVerifier: String,
            state: String,
            onSuccess: @escaping (String, String, String?) -> Void,
            onError: @escaping (Error) -> Void
        ) {
            self.codeVerifier = codeVerifier
            self.state = state
            self.onSuccess = onSuccess
            self.onError = onError
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            
            // Check if this is our callback URL (case-insensitive for scheme)
            let callbackScheme = "overlookme://"
            if url.absoluteString.lowercased().starts(with: callbackScheme.lowercased()) {
                decisionHandler(.cancel)
                handleCallback(url: url)
                return
            }
            
            decisionHandler(.allow)
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {}
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {}
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {}
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            onError(error)
        }
        
        private func handleCallback(url: URL) {
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let queryItems = components.queryItems else {
                onError(WebViewError.invalidCallback)
                return
            }
            
            // Check for error response from Auth0
            if let error = queryItems.first(where: { $0.name == "error" })?.value {
                let errorDescription = queryItems.first(where: { $0.name == "error_description" })?.value ?? "Unknown error"
                onError(WebViewError.auth0Error(error: error, description: errorDescription))
                return
            }
            
            // Extract authorization code and state
            guard let code = queryItems.first(where: { $0.name == "code" })?.value else {
                onError(WebViewError.invalidCallback)
                return
            }
            
            guard let returnedState = queryItems.first(where: { $0.name == "state" })?.value else {
                onError(WebViewError.invalidCallback)
                return
            }
            
            guard returnedState == state else {
                onError(WebViewError.invalidCallback)
                return
            }
            
            // Exchange code for tokens
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
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw WebViewError.tokenExchangeFailed
            }
            
            if httpResponse.statusCode != 200 {
                throw WebViewError.tokenExchangeFailed
            }
            
            return try JSONDecoder().decode(TokenResponse.self, from: data)
        }
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
    case invalidCallback
    case tokenExchangeFailed
    case auth0Error(error: String, description: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidCallback:
            return "Invalid authorization callback"
        case .tokenExchangeFailed:
            return "Failed to exchange code for tokens"
        case .auth0Error(let error, let description):
            return "Auth0 Error: \(error) - \(description)"
        }
    }
}
