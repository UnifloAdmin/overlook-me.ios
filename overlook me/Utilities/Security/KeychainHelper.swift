//
//  KeychainHelper.swift
//  overlook me
//
//  Created by Naresh Chandra on 1/8/26.
//

import Foundation
import Security

/// Secure storage using Keychain
enum KeychainHelper {
    private static let service = "com.uniflo.overlookme"
    
    enum Key: String {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
        case userData = "user_data"
    }
    
    // MARK: - Save
    
    static func save(_ data: Data, for key: Key) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data
        ]
        
        // Delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }
    
    static func save(_ string: String, for key: Key) throws {
        guard let data = string.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        try save(data, for: key)
    }
    
    // MARK: - Retrieve
    
    static func retrieve(for key: Key) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data else {
            throw KeychainError.retrieveFailed(status)
        }
        
        return data
    }
    
    static func retrieveString(for key: Key) throws -> String {
        let data = try retrieve(for: key)
        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        return string
    }
    
    // MARK: - Delete
    
    static func delete(for key: Key) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
    
    static func deleteAll() throws {
        for key in Key.allCases {
            try? delete(for: key)
        }
    }
}

// MARK: - Key Cases

extension KeychainHelper.Key: CaseIterable {}

// MARK: - Errors

enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)
    case retrieveFailed(OSStatus)
    case deleteFailed(OSStatus)
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Failed to save to Keychain: \(status)"
        case .retrieveFailed(let status):
            return "Failed to retrieve from Keychain: \(status)"
        case .deleteFailed(let status):
            return "Failed to delete from Keychain: \(status)"
        case .invalidData:
            return "Invalid data format"
        }
    }
}
