import Foundation

struct URLSessionAPIClient: APIClient {
    let baseURL: URL
    let tokenProvider: (any AuthTokenProviding)?
    let responseDecoder: ResponseDecoder

    let session: URLSession
    let jsonEncoder: JSONEncoder
    let jsonDecoder: JSONDecoder

    init(
        baseURL: URL,
        tokenProvider: (any AuthTokenProviding)? = nil,
        responseDecoder: ResponseDecoder = ResponseDecoder(config: nil),
        session: URLSession = .shared,
        jsonEncoder: JSONEncoder = JSONEncoder(),
        jsonDecoder: JSONDecoder = JSONDecoder()
    ) {
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
        self.responseDecoder = responseDecoder
        self.session = session
        self.jsonEncoder = jsonEncoder
        self.jsonDecoder = jsonDecoder
    }

    func request<T: Decodable>(
        _ method: HTTPMethod,
        path: String,
        query: [String: String?] = [:],
        headers: [String: String] = [:],
        body: (any Encodable)? = nil
    ) async throws -> T {
        let url = try makeURL(path: path, query: query)

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let token = await tokenProvider?.accessToken(), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try jsonEncoder.encode(AnyEncodable(body))
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            throw APIError.httpStatus(http.statusCode, body: data)
        }

        let decodedData = try responseDecoder.decodeIfNeeded(data)

        // Allow empty bodies for endpoints returning no content.
        if decodedData.isEmpty, T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }

        do {
            return try jsonDecoder.decode(T.self, from: decodedData)
        } catch {
            throw APIError.decodingFailed(error)
        }
    }

    private func makeURL(path: String, query: [String: String?]) throws -> URL {
        let cleaned = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let base = baseURL.appendingPathComponent(cleaned)
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }

        let items = query.compactMap { key, value -> URLQueryItem? in
            guard let value else { return nil }
            return URLQueryItem(name: key, value: value)
        }
        if !items.isEmpty { components.queryItems = items }

        guard let url = components.url else { throw APIError.invalidURL }
        return url
    }
}

/// Type-erased `Encodable` wrapper to encode request bodies.
private struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void

    init(_ encodable: any Encodable) {
        self._encode = encodable.encode
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}

