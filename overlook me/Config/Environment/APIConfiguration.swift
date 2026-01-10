import Foundation

enum APIConfiguration {
    /// Base URL sourced from `environment.prod.ts` in the web client.
    static let baseURL = URL(string: "https://uniflo-data.com/api")!

    /// Matches `environment.prod.ts` -> `responseEncoding`.
    static let responseEncoding = ResponseEncodingConfiguration(
        enabled: true,
        encodingType: .aes,
        encryptionKey: "Unif10@2024#SecureAES256Key!$"
    )
}

