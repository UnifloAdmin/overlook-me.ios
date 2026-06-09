import CryptoKit
import Foundation
import UIKit

struct DeviceInfoPayload {
    let deviceFingerprint: String
    let deviceInfo: String
    let deviceName: String
    let deviceModel: String
    let osVersion: String
    let appVersion: String

    var bodyFields: [String: Any] {
        [
            "deviceFingerprint": deviceFingerprint,
            "deviceInfo": deviceInfo,
            "deviceName": deviceName,
            "deviceModel": deviceModel,
            "osVersion": osVersion,
            "appVersion": appVersion
        ]
    }
}

enum DeviceInfoCollector {
    static func collect() -> DeviceInfoPayload {
        let device = UIDevice.current
        let modelIdentifier = Self.modelIdentifier()
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        let osVersion = "\(device.systemName) \(device.systemVersion)"
        let vendorId = device.identifierForVendor?.uuidString ?? "unknown-vendor"
        let bundleId = Bundle.main.bundleIdentifier ?? "com.uniflo.overlookme"
        let fingerprintSeed = "\(bundleId)|\(vendorId)|\(modelIdentifier)"
        let fingerprint = SHA256.hash(data: Data(fingerprintSeed.utf8))
            .map { String(format: "%02x", $0) }
            .joined()

        return DeviceInfoPayload(
            deviceFingerprint: fingerprint,
            deviceInfo: "\(device.name) / \(modelIdentifier) / \(osVersion) / \(appVersion)(\(buildNumber))",
            deviceName: device.name,
            deviceModel: modelIdentifier,
            osVersion: osVersion,
            appVersion: "\(appVersion)(\(buildNumber))"
        )
    }

    private static func modelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        return mirror.children.reduce(into: "") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            identifier.append(String(UnicodeScalar(UInt8(value))))
        }
    }
}
