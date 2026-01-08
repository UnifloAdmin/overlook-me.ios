//
//  Credentials.swift
//  overlook me
//
//  Created by Naresh Chandra on 1/8/26.
//

import Foundation

/// Authentication credentials
struct Credentials: Codable {
    let accessToken: String
    let idToken: String
    let refreshToken: String?
    let expiresIn: Date
    let scope: String?
    let tokenType: String
    
    var isExpired: Bool {
        Date() >= expiresIn
    }
}
