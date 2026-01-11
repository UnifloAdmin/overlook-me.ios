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
    
    enum CodingKeys: String, CodingKey {
        case id = "sub"
        case oauthId = "oauthId"
        case email
        case name
        case picture
        case emailVerified = "email_verified"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        let oauthId = try container.decodeIfPresent(String.self, forKey: .oauthId) ?? id
        let email = try container.decode(String.self, forKey: .email)
        let name = try container.decodeIfPresent(String.self, forKey: .name)
        let picture = try container.decodeIfPresent(String.self, forKey: .picture)
        let emailVerified = try container.decodeIfPresent(Bool.self, forKey: .emailVerified) ?? false
        
        self.init(
            id: id,
            oauthId: oauthId,
            email: email,
            name: name,
            picture: picture,
            emailVerified: emailVerified
        )
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(oauthId, forKey: .oauthId)
        try container.encode(email, forKey: .email)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(picture, forKey: .picture)
        try container.encode(emailVerified, forKey: .emailVerified)
    }
}
