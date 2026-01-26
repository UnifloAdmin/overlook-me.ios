import Foundation

enum APIConfiguration {
    /// Base URL - automatically switches to localhost when running in simulator
    static let baseURL: URL = {
        #if targetEnvironment(simulator)
        // Use localhost for iOS Simulator (your Mac's localhost)
        let url = URL(string: "http://localhost:5273/api")!
        print("🔧 [APIConfiguration] SIMULATOR DETECTED - Using localhost: \(url.absoluteString)")
        return url
        #else
        // Use production URL for real devices
        let url = URL(string: "https://uniflo-data.com/api")!
        print("📱 [APIConfiguration] DEVICE/PRODUCTION - Using production: \(url.absoluteString)")
        return url
        #endif
    }()

    /// Response encoding configuration
    /// Note: Disable encryption for localhost development if needed
    static let responseEncoding: ResponseEncodingConfiguration = {
        #if targetEnvironment(simulator)
        // Disable encryption for local development (optional - adjust as needed)
        print("🔧 [APIConfiguration] SIMULATOR - Encryption DISABLED for debugging")
        return ResponseEncodingConfiguration(
            enabled: false,
            encodingType: .aes,
            encryptionKey: "Unif10@2024#SecureAES256Key!$"
        )
        #else
        // Enable encryption for production
        print("📱 [APIConfiguration] PRODUCTION - Encryption ENABLED")
        return ResponseEncodingConfiguration(
            enabled: true,
            encodingType: .aes,
            encryptionKey: "Unif10@2024#SecureAES256Key!$"
        )
        #endif
    }()
    
    /// Debug helper to verify configuration at runtime
    static func printConfiguration() {
        print("=" * 60)
        print("📋 API Configuration Status")
        print("=" * 60)
        #if targetEnvironment(simulator)
        print("🔧 Environment: iOS Simulator")
        #else
        print("📱 Environment: Physical Device")
        #endif
        print("🌐 Base URL: \(baseURL.absoluteString)")
        print("🔐 Encryption Enabled: \(responseEncoding.enabled)")
        print("=" * 60)
    }
}

private func * (lhs: String, rhs: Int) -> String {
    String(repeating: lhs, count: rhs)
}

