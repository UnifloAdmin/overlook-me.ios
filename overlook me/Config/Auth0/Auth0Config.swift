//
//  CAMAConfig.swift
//  overlook me
//
//  CAMA authentication API configuration
//

import Foundation

/// CAMA authentication API configuration
enum CAMAConfig {
    static let baseURL = "https://cama-prod.thankfulcoast-60df155d.eastus.azurecontainerapps.io/api"
    
    // Auth endpoints
    static var authURL: String { "\(baseURL)/Auth" }
    static var loginURL: String { "\(authURL)/login" }
    static var registerURL: String { "\(authURL)/register" }
    static var refreshTokenURL: String { "\(authURL)/refresh-token" }
    static var logoutURL: String { "\(authURL)/logout" }
    static var forgotPasswordURL: String { "\(authURL)/forgot-password" }
    static var changePasswordURL: String { "\(authURL)/change-password" }
    static var confirmEmailURL: String { "\(authURL)/confirm-email" }
    static var resendVerificationURL: String { "\(authURL)/resend-verification-email" }
    static var emailStatusURL: String { "\(authURL)/email-status" }
    
    // Two-factor endpoints
    static var twoFactorURL: String { "\(baseURL)/TwoFactor" }
    static var twoFactorSetupURL: String { "\(twoFactorURL)/setup" }
    static var twoFactorEnableURL: String { "\(twoFactorURL)/enable" }
    static var twoFactorDisableURL: String { "\(twoFactorURL)/disable" }
    static var twoFactorVerifyLoginURL: String { "\(twoFactorURL)/verify-login" }
    static var twoFactorStatusURL: String { "\(twoFactorURL)/status" }
    static var twoFactorDevicesURL: String { "\(twoFactorURL)/devices" }
}
