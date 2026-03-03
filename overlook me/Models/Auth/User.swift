//
//  User.swift
//  overlook me
//
//  Created by Naresh Chandra on 1/8/26.
//

import Foundation

/// User profile model
struct User: Codable, Equatable {
    let id: String
    let oauthId: String
    let email: String
    let name: String?
    let picture: String?
    let emailVerified: Bool
    
    init(
        id: String,
        oauthId: String? = nil,
        email: String,
        name: String?,
        picture: String?,
        emailVerified: Bool
    ) {
        self.id = id
        self.oauthId = oauthId ?? id
        self.email = email
        self.name = name
        self.picture = picture
        self.emailVerified = emailVerified
    }
}
