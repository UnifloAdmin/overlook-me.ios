// PasskeyService.swift
// overlook me
//
// Wraps ASAuthorizationController for passkey registration & assertion.

import AuthenticationServices
import Foundation

// MARK: - Passkey Results

struct PasskeyRegistrationResult {
    let credentialID: Data
    let rawAttestationObject: Data
    let rawClientDataJSON: Data
}

struct PasskeyAssertionResult {
    let credentialID: Data
    let rawAuthenticatorData: Data
    let rawClientDataJSON: Data
    let signature: Data
    let userID: Data
}

// MARK: - PasskeyService

@MainActor
final class PasskeyService: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {

    private var registrationContinuation: CheckedContinuation<PasskeyRegistrationResult, Error>?
    private var assertionContinuation: CheckedContinuation<PasskeyAssertionResult, Error>?

    // MARK: - Registration

    func register(challengeData: Data, userID: Data, userName: String, rpID: String) async throws -> PasskeyRegistrationResult {
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rpID)
        let request = provider.createCredentialRegistrationRequest(
            challenge: challengeData,
            name: userName,
            userID: userID
        )

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self

        return try await withCheckedThrowingContinuation { continuation in
            self.registrationContinuation = continuation
            controller.performRequests()
        }
    }

    // MARK: - Assertion (login)

    func authenticate(challengeData: Data, rpID: String, allowedCredentialIDs: [Data]? = nil) async throws -> PasskeyAssertionResult {
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rpID)
        let request = provider.createCredentialAssertionRequest(challenge: challengeData)

        if let ids = allowedCredentialIDs, !ids.isEmpty {
            request.allowedCredentials = ids.map {
                ASAuthorizationPlatformPublicKeyCredentialDescriptor(credentialID: $0)
            }
        }

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self

        return try await withCheckedThrowingContinuation { continuation in
            self.assertionContinuation = continuation
            controller.performRequests()
        }
    }

    // MARK: - ASAuthorizationControllerDelegate

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        let credential = authorization.credential
        _Concurrency.Task {
            await MainActor.run {
                if let reg = credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration {
                    let result = PasskeyRegistrationResult(
                        credentialID: reg.credentialID,
                        rawAttestationObject: reg.rawAttestationObject ?? Data(),
                        rawClientDataJSON: reg.rawClientDataJSON
                    )
                    registrationContinuation?.resume(returning: result)
                    registrationContinuation = nil
                } else if let assertion = credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion {
                    let result = PasskeyAssertionResult(
                        credentialID: assertion.credentialID,
                        rawAuthenticatorData: assertion.rawAuthenticatorData,
                        rawClientDataJSON: assertion.rawClientDataJSON,
                        signature: assertion.signature,
                        userID: assertion.userID
                    )
                    assertionContinuation?.resume(returning: result)
                    assertionContinuation = nil
                }
            }
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let err = error
        _Concurrency.Task {
            await MainActor.run {
                if let c = registrationContinuation {
                    c.resume(throwing: err)
                    registrationContinuation = nil
                }
                if let c = assertionContinuation {
                    c.resume(throwing: err)
                    assertionContinuation = nil
                }
            }
        }
    }

    // MARK: - Presentation Context

    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Return the key window from any connected scene
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        return windowScene?.windows.first(where: \.isKeyWindow) ?? UIWindow()
    }
}
