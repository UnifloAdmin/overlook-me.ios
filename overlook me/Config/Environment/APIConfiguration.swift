import Foundation

enum APIConfiguration {
    static let baseURL: URL = {
        #if targetEnvironment(simulator)
        let url = URL(string: "https://eyrie.overlookme.com/api")!
        print("[APIConfiguration] SIMULATOR DETECTED - Using staging: \(url.absoluteString)")
        return url
        #else
        let url = URL(string: "https://eyrie.overlookme.com/api")!
        print("[APIConfiguration] DEVICE/PRODUCTION - Using production: \(url.absoluteString)")
        return url
        #endif
    }()

    static let responseEncoding: ResponseEncodingConfiguration = {
        #if targetEnvironment(simulator)
        print("[APIConfiguration] SIMULATOR - Encryption DISABLED for debugging")
        return ResponseEncodingConfiguration(
            enabled: false,
            encodingType: .aes,
            encryptionKey: "Unif10@2024#SecureAES256Key!$"
        )
        #else
        print("[APIConfiguration] PRODUCTION - Encryption ENABLED")
        return ResponseEncodingConfiguration(
            enabled: true,
            encodingType: .aes,
            encryptionKey: "Unif10@2024#SecureAES256Key!$"
        )
        #endif
    }()
    
    static func printConfiguration() {
        print("=" * 60)
        print("API Configuration Status")
        print("=" * 60)
        #if targetEnvironment(simulator)
        print("Environment: iOS Simulator")
        #else
        print("Environment: Physical Device")
        #endif
        print("Base URL: \(baseURL.absoluteString)")
        print("Encryption Enabled: \(responseEncoding.enabled)")
        print("=" * 60)
    }
}

private func * (lhs: String, rhs: Int) -> String {
    String(repeating: lhs, count: rhs)
}
