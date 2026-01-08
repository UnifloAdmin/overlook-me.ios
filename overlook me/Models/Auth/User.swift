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
    let email: String
    let name: String?
    let picture: String?
    let emailVerified: Bool
    
    enum CodingKeys: String, CodingKey {
        case id = "sub"
        case email
        case name
        case picture
        case emailVerified = "email_verified"
    }
}
