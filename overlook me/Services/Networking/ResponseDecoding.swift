import Foundation

struct ResponseEncodingConfiguration: Sendable {
    enum EncodingType: String, Sendable {
        case base64
        case binary
        case hex
        case xor
        case aes
    }

    var enabled: Bool
    var encodingType: EncodingType
    var encryptionKey: String
}

/// Decodes backend responses that come in `{ data: string, encoding: string }` envelope.
/// Mirrors the web client's `ResponseDecoderService`.
struct ResponseDecoder: Sendable {
    let config: ResponseEncodingConfiguration?

    func decodeIfNeeded(_ raw: Data) throws -> Data {
        guard let config, config.enabled else { return raw }

        // If it isn't JSON, return as-is.
        guard
            let obj = try? JSONSerialization.jsonObject(with: raw, options: []),
            let dict = obj as? [String: Any]
        else { return raw }

        // Handle both lowercase and capitalized keys (data/Data, encoding/Encoding)
        let payload = (dict["data"] ?? dict["Data"]) as? String
        let encodingStr = ((dict["encoding"] ?? dict["Encoding"]) as? String) ?? config.encodingType.rawValue

        guard let payload, !payload.isEmpty else { return raw }

        let decodedObj: Any
        switch encodingStr.lowercased() {
        case "base64":
            decodedObj = try decodeBase64(payload)
        case "binary":
            decodedObj = try decodeBinary(payload)
        case "hex":
            decodedObj = try decodeHex(payload)
        case "xor":
            decodedObj = try decodeXor(payload, key: config.encryptionKey)
        case "aes":
            decodedObj = try decodeAes(payload, key: config.encryptionKey)
        default:
            return raw
        }

        return try JSONSerialization.data(withJSONObject: decodedObj, options: [])
    }

    private func decodeBase64(_ encoded: String) throws -> Any {
        guard let data = Data(base64Encoded: encoded) else {
            throw APIError.responseDecodingFailed("Invalid base64 payload")
        }
        return try jsonObject(fromUTF8: data)
    }

    private func decodeBinary(_ binary: String) throws -> Any {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(binary.count / 8)

        var idx = binary.startIndex
        while idx < binary.endIndex {
            let next = binary.index(idx, offsetBy: 8, limitedBy: binary.endIndex) ?? binary.endIndex
            let chunk = String(binary[idx..<next])
            if chunk.count == 8, let value = UInt8(chunk, radix: 2) {
                bytes.append(value)
            }
            idx = next
        }

        return try jsonObject(fromUTF8: Data(bytes))
    }

    private func decodeHex(_ hex: String) throws -> Any {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(hex.count / 2)

        var idx = hex.startIndex
        while idx < hex.endIndex {
            let next = hex.index(idx, offsetBy: 2, limitedBy: hex.endIndex) ?? hex.endIndex
            let chunk = String(hex[idx..<next])
            if chunk.count == 2, let value = UInt8(chunk, radix: 16) {
                bytes.append(value)
            }
            idx = next
        }

        return try jsonObject(fromUTF8: Data(bytes))
    }

    private func decodeXor(_ encoded: String, key: String) throws -> Any {
        guard let encrypted = Data(base64Encoded: encoded) else {
            throw APIError.responseDecodingFailed("Invalid base64 payload for XOR")
        }

        let keyBytes = Array(key.utf8)
        guard !keyBytes.isEmpty else {
            throw APIError.responseDecodingFailed("Missing XOR key")
        }

        var out = [UInt8](repeating: 0, count: encrypted.count)
        for i in 0..<encrypted.count {
            out[i] = encrypted[i] ^ keyBytes[i % keyBytes.count]
        }

        return try jsonObject(fromUTF8: Data(out))
    }

    private func decodeAes(_ encrypted: String, key: String) throws -> Any {
        guard let encryptedData = Data(base64Encoded: encrypted) else {
            throw APIError.responseDecodingFailed("Invalid base64 payload for AES")
        }
        guard encryptedData.count > 16 else {
            throw APIError.responseDecodingFailed("Invalid AES payload length")
        }

        let iv = encryptedData.prefix(16)
        let ciphertext = encryptedData.dropFirst(16)

        // Match web client: UTF8 bytes truncated/padded to 32 bytes.
        var keyBytes = [UInt8](repeating: 0, count: 32)
        let provided = Array(key.utf8)
        keyBytes.replaceSubrange(0..<min(32, provided.count), with: provided.prefix(32))

        let plaintext = try AES256CBC.decrypt(ciphertext: Data(ciphertext), key: Data(keyBytes), iv: Data(iv))
        return try jsonObject(fromUTF8: plaintext)
    }

    private func jsonObject(fromUTF8 data: Data) throws -> Any {
        guard let text = String(data: data, encoding: .utf8), !text.isEmpty else {
            throw APIError.responseDecodingFailed("Decoded payload is empty or not UTF-8")
        }
        guard let jsonData = text.data(using: .utf8) else {
            throw APIError.responseDecodingFailed("Failed to re-encode decoded payload")
        }
        return try JSONSerialization.jsonObject(with: jsonData, options: [])
    }
}

