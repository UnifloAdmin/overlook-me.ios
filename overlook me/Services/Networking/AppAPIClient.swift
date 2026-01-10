import Foundation

enum AppAPIClient {
    static func live() -> URLSessionAPIClient {
        URLSessionAPIClient(
            baseURL: APIConfiguration.baseURL,
            tokenProvider: KeychainAuthTokenProvider(),
            responseDecoder: ResponseDecoder(config: APIConfiguration.responseEncoding)
        )
    }
}

