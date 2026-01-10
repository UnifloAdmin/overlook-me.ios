import Foundation

/// Lightweight decorator to log outgoing requests.
/// Note: This logs the explicit parameters passed into `APIClient.request(...)`.
/// Authorization headers added internally by concrete clients may not be visible here.
struct LoggingAPIClient: APIClient {
    let base: any APIClient
    let log: @Sendable (String) -> Void

    init(base: any APIClient, log: @escaping @Sendable (String) -> Void = { print($0) }) {
        self.base = base
        self.log = log
    }

    func request<T: Decodable>(
        _ method: HTTPMethod,
        path: String,
        query: [String: String?],
        headers: [String: String],
        body: (any Encodable)?
    ) async throws -> T {
        log(makeMessage(method: method, path: path, query: query, headers: headers, body: body))
        return try await base.request(method, path: path, query: query, headers: headers, body: body)
    }

    private func makeMessage(
        method: HTTPMethod,
        path: String,
        query: [String: String?],
        headers: [String: String],
        body: (any Encodable)?
    ) -> String {
        let cleanedQuery = query.compactMapValues { $0 }
        let sortedQuery = cleanedQuery.keys.sorted().map { "\($0)=\(cleanedQuery[$0] ?? "")" }.joined(separator: "&")
        let headersString = headers
            .keys
            .sorted()
            .map { "\($0): \(headers[$0] ?? "")" }
            .joined(separator: ", ")

        var lines: [String] = []
        lines.append("API Request:")
        lines.append("- method: \(method.rawValue)")
        lines.append("- path: \(path)")
        lines.append("- query: \(sortedQuery.isEmpty ? "(none)" : sortedQuery)")
        lines.append("- headers: \(headersString.isEmpty ? "(none)" : headersString)")
        lines.append("- body: \(body == nil ? "(none)" : String(describing: body!))")
        return lines.joined(separator: "\n")
    }
}

