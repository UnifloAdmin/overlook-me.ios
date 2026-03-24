import Foundation

enum APIConfiguration {
    // ──────────────────────────────────────────────
    // MARK: – Base URL (uniflo.api)
    // ──────────────────────────────────────────────
    static let baseURL: URL = {
        switch ServerEnvironment.current {
        case .local:
            // uniflo.api runs on http://localhost:5273
            let url = URL(string: "http://localhost:5273/api")!
            print("[APIConfiguration] LOCAL - Using localhost: \(url.absoluteString)")
            return url
        case .staging:
            let url = URL(string: "https://eyrie.overlookme.com/api")!
            print("[APIConfiguration] STAGING - Using staging: \(url.absoluteString)")
            return url
        case .production:
            let url = URL(string: "https://eyrie.overlookme.com/api")!
            print("[APIConfiguration] PRODUCTION - Using production: \(url.absoluteString)")
            return url
        }
    }()

    // ──────────────────────────────────────────────
    // MARK: – Response Encoding
    // ──────────────────────────────────────────────
    static let responseEncoding: ResponseEncodingConfiguration = {
        switch ServerEnvironment.current {
        case .local:
            print("[APIConfiguration] LOCAL - Encryption DISABLED for debugging")
            return ResponseEncodingConfiguration(
                enabled: false,
                encodingType: .aes,
                encryptionKey: "Unif10@2024#SecureAES256Key!$"
            )
        case .staging:
            print("[APIConfiguration] STAGING - Encryption DISABLED for debugging")
            return ResponseEncodingConfiguration(
                enabled: false,
                encodingType: .aes,
                encryptionKey: "Unif10@2024#SecureAES256Key!$"
            )
        case .production:
            print("[APIConfiguration] PRODUCTION - Encryption ENABLED")
            return ResponseEncodingConfiguration(
                enabled: true,
                encodingType: .aes,
                encryptionKey: "Unif10@2024#SecureAES256Key!$"
            )
        }
    }()
    
    // ──────────────────────────────────────────────
    // MARK: – Debug Helper
    // ──────────────────────────────────────────────
    static func printConfiguration() {
        print("=" * 60)
        print("API Configuration Status")
        print("=" * 60)
        print("Environment: \(ServerEnvironment.current)")
        print("Base URL: \(baseURL.absoluteString)")
        print("Encryption Enabled: \(responseEncoding.enabled)")
        print("=" * 60)
    }
}

private func * (lhs: String, rhs: Int) -> String {
    String(repeating: lhs, count: rhs)
}
