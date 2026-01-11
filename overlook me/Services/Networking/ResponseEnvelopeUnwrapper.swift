import Foundation

/// Attempts to unwrap common `{ message, payload }` response envelopes so feature
/// code can keep decoding straight into the payload model (`DailyHabitDTO`, etc.).
enum ResponseEnvelopeUnwrapper {
    private static let ignoredKeys: Set<String> = [
        "message",
        "status",
        "success",
        "code",
        "error",
        "errors",
        "timestamp",
        "requestid",
        "request_id",
        "encoding"
    ]
    
    private static let preferredPayloadKeys: [String] = [
        "habit",
        "task",
        "payload",
        "result",
        "data"
    ]
    
    static func unwrap(_ data: Data) -> Data? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data, options: []),
            let dict = json as? [String: Any]
        else {
            return nil
        }
        
        // Explicit `data` key that already contains nested JSON (not encoded string).
        if
            let nestedData = dict["data"],
            !(nestedData is String),
            !(nestedData is NSNull),
            let encoded = encodeJSONCompatible(nestedData)
        {
            return encoded
        }
        
        // Try preferred domain-specific keys first.
        for key in preferredPayloadKeys where key != "data" {
            if let value = dict[key], !(value is NSNull), let encoded = encodeJSONCompatible(value) {
                return encoded
            }
        }
        
        // Otherwise fall back to any non-metadata key.
        let candidates = dict.filter { key, value in
            let lower = key.lowercased()
            guard !ignoredKeys.contains(lower), !(value is NSNull) else { return false }
            return true
        }
        
        guard candidates.count == 1, let value = candidates.first?.value else {
            return nil
        }
        
        return encodeJSONCompatible(value)
    }
    
    private static func encodeJSONCompatible(_ value: Any) -> Data? {
        guard JSONSerialization.isValidJSONObject(value) else {
            return nil
        }
        return try? JSONSerialization.data(withJSONObject: value, options: [])
    }
}

