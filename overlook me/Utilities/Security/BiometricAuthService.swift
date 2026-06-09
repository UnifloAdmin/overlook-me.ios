import Foundation
import LocalAuthentication

enum BiometricAuthError: LocalizedError {
    case notAvailable
    case authenticationFailed

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Biometric authentication is not available on this device."
        case .authenticationFailed:
            return "Face ID authentication failed."
        }
    }
}

struct BiometricAuthService {
    func authenticate(reason: String) async throws -> Bool {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw BiometricAuthError.notAvailable
        }

        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
        } catch {
            throw BiometricAuthError.authenticationFailed
        }
    }
}
