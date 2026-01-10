import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpStatus(Int, body: Data?)
    case decodingFailed(Error)
    case responseDecodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid HTTP response"
        case .httpStatus(let code, _):
            return "HTTP error \(code)"
        case .decodingFailed(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .responseDecodingFailed(let message):
            return "Failed to decode encoded response: \(message)"
        }
    }
}

