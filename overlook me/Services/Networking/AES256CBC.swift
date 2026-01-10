import Foundation
import CommonCrypto

enum AES256CBC {
    static func decrypt(ciphertext: Data, key: Data, iv: Data) throws -> Data {
        guard key.count == kCCKeySizeAES256 else {
            throw APIError.responseDecodingFailed("AES key must be 32 bytes")
        }
        guard iv.count == kCCBlockSizeAES128 else {
            throw APIError.responseDecodingFailed("AES IV must be 16 bytes")
        }

        let outputCapacity = ciphertext.count + kCCBlockSizeAES128
        var outLength: size_t = 0
        var out = Data(count: outputCapacity)

        let status = out.withUnsafeMutableBytes { outBytes in
            ciphertext.withUnsafeBytes { cipherBytes in
                iv.withUnsafeBytes { ivBytes in
                    key.withUnsafeBytes { keyBytes in
                        CCCrypt(
                            CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress,
                            key.count,
                            ivBytes.baseAddress,
                            cipherBytes.baseAddress,
                            ciphertext.count,
                            outBytes.baseAddress,
                            outputCapacity,
                            &outLength
                        )
                    }
                }
            }
        }

        guard status == kCCSuccess else {
            throw APIError.responseDecodingFailed("AES decrypt failed with status \(status)")
        }

        out.removeSubrange(outLength..<out.count)
        return out
    }
}

