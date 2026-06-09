import Foundation

struct DeviceTrustManager {
    private let repository: AuthRepository

    init(repository: AuthRepository) {
        self.repository = repository
    }

    func validateTrustedDevice() async -> CAMAAuthResponse? {
        let deviceInfo = DeviceInfoCollector.collect()

        guard let storedFingerprint = try? KeychainHelper.retrieveString(for: .deviceFingerprint),
              storedFingerprint == deviceInfo.deviceFingerprint,
              let trustToken = try? KeychainHelper.retrieveBiometricProtectedString(
                for: .deviceTrustToken,
                prompt: "Use Face ID to unlock Overlook Me."
              ) else {
            return nil
        }

        return try? await repository.validateDeviceTrust(
            token: trustToken,
            fingerprint: deviceInfo.deviceFingerprint,
            deviceInfo: deviceInfo
        )
    }

    func storeDeviceTrustToken(_ token: String?) {
        guard let token, !token.isEmpty else { return }

        let deviceInfo = DeviceInfoCollector.collect()
        try? KeychainHelper.save(deviceInfo.deviceFingerprint, for: .deviceFingerprint)
        try? KeychainHelper.saveBiometricProtected(token, for: .deviceTrustToken)
    }

    func clearTrustedDevice() {
        try? KeychainHelper.delete(for: .deviceTrustToken)
        try? KeychainHelper.delete(for: .deviceFingerprint)
    }
}
