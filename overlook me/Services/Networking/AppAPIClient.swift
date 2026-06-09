import Foundation

enum AppAPIClient {
    static func live() -> URLSessionAPIClient {
        URLSessionAPIClient(
            baseURL: APIConfiguration.baseURL,
            tokenProvider: KeychainAuthTokenProvider(),
            tokenRefresher: KeychainAuthTokenRefresher(),
            responseDecoder: ResponseDecoder(config: APIConfiguration.responseEncoding)
        )
    }
}

