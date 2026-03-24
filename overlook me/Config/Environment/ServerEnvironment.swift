import Foundation

/// Defines the available server environments for API connections.
/// Change `current` to switch between local development, staging, and production.
enum ServerEnvironment {
    case local       // Connect to localhost backends
    case staging     // Staging / test server
    case production  // Live production server

    // ──────────────────────────────────────────────
    // MARK: – Active environment
    // ──────────────────────────────────────────────
    /// Toggle this value to switch the entire app's API target.
    #if targetEnvironment(simulator)
    static let current: ServerEnvironment = .local
    #else
    static let current: ServerEnvironment = .production
    #endif
}
