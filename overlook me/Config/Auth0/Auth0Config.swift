//
//  Auth0Config.swift
//  overlook me
//
//  Created by Naresh Chandra on 1/8/26.
//

import Foundation

/// Auth0 configuration
enum Auth0Config {
    // Load from Auth0Secrets file (not committed to git)
    static let domain = Auth0Secrets.domain
    static let clientId = Auth0Secrets.clientId
    static let clientSecret = Auth0Secrets.clientSecret
    
    static let scope = "openid profile email offline_access"
    static let audience = "" // No audience required
    
    // Callback uses bundle identifier to guarantee uniqueness
    static var callbackURL: String {
        let bundleId = Bundle.main.bundleIdentifier ?? "Uniflo.overlook-me"
        return "overlookme://\(bundleId)/callback"
    }
}
