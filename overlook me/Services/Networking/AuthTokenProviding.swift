import Foundation

protocol AuthTokenProviding: Sendable {
    func accessToken() async -> String?
}

struct KeychainAuthTokenProvider: AuthTokenProviding {
    func accessToken() async -> String? {
        (try? KeychainHelper.retrieveString(for: .accessToken))
    }
}

