import Foundation

protocol AuthTokenProviding: Sendable {
    func accessToken() async -> String?
}

/// Provides silent token refresh capability to the API client.
/// When a 401 is received, the client calls `refreshAndReturnToken()`
/// to get a fresh access token, then retries the request once.
protocol AuthTokenRefreshing: Sendable {
    func refreshAndReturnToken() async -> String?
}

struct KeychainAuthTokenProvider: AuthTokenProviding {
    func accessToken() async -> String? {
        (try? KeychainHelper.retrieveString(for: .accessToken))
    }
}

/// Refreshes tokens via CAMA and returns the new access token.
/// On success the new tokens are saved to Keychain automatically.
///
/// **Serialized**: Multiple concurrent 401 retries share a single
/// in-flight refresh to avoid burning the single-use refresh token.
struct KeychainAuthTokenRefresher: AuthTokenRefreshing {

    func refreshAndReturnToken() async -> String? {
        await TokenRefreshCoordinator.shared.refreshOnce()
    }
}

// MARK: - Serialized Token Refresh

/// Ensures only ONE token refresh runs at a time.
/// When 5 concurrent API calls all get 401, the first one triggers the
/// refresh and the other 4 piggy-back on the same in-flight task.
/// This prevents "refresh token already used" failures.
@globalActor
actor TokenRefreshActor {
    static let shared = TokenRefreshActor()
}

final class TokenRefreshCoordinator: Sendable {
    static let shared = TokenRefreshCoordinator()

    // Mutable state protected by an actor
    private let state = RefreshState()

    func refreshOnce() async -> String? {
        // If there's already an in-flight refresh, wait for it
        if let existing = await state.inFlightTask {
            print("🔄 [TokenRefreshCoordinator] Piggy-backing on existing refresh")
            return await existing.value
        }

        // Start a new refresh
        let task = _Concurrency.Task<String?, Never> {
            defer { _Concurrency.Task { await self.state.clearTask() } }
            return await self.doRefresh()
        }

        await state.setTask(task)
        return await task.value
    }

    private func doRefresh() async -> String? {
        guard let accessToken = try? KeychainHelper.retrieveString(for: .accessToken),
              let refreshToken = try? KeychainHelper.retrieveString(for: .refreshToken) else {
            print("🔄 [TokenRefreshCoordinator] No tokens in keychain")
            return nil
        }

        do {
            print("🔄 [TokenRefreshCoordinator] Refreshing token...")
            let repo = RealAuthRepository()
            let response = try await repo.refreshToken(
                accessToken: accessToken,
                refreshToken: refreshToken,
                deviceInfo: DeviceInfoCollector.collect()
            )
            guard let newAccess = response.accessToken, let newRefresh = response.refreshToken else {
                print("❌ [TokenRefreshCoordinator] Response missing tokens")
                return nil
            }

            try? KeychainHelper.save(newAccess, for: .accessToken)
            try? KeychainHelper.save(newRefresh, for: .refreshToken)
            if let sessionId = response.sessionId {
                try? KeychainHelper.save(sessionId, for: .sessionId)
            }
            print("✅ [TokenRefreshCoordinator] Token refreshed successfully (new session: \(response.sessionId ?? "same"))")
            return newAccess
        } catch {
            print("❌ [TokenRefreshCoordinator] Refresh failed: \(error.localizedDescription)")
            return nil
        }
    }
}

// Actor-isolated mutable state
private actor RefreshState {
    var inFlightTask: _Concurrency.Task<String?, Never>?

    func setTask(_ task: _Concurrency.Task<String?, Never>) {
        inFlightTask = task
    }

    func clearTask() {
        inFlightTask = nil
    }
}
