import Foundation
import SwiftUI
import Combine
import LinkKit

// MARK: - Plaid Link Manager

/// Manages Plaid Link SDK integration for connecting bank accounts
@MainActor
final class PlaidLinkManager: ObservableObject {
    
    // MARK: - Published State
    
    @Published var isLoading = false
    @Published var isLinkReady = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    // MARK: - Private Properties
    
    private let plaidAPI: PlaidAPI
    private var linkHandler: Handler?
    private var currentUserId: String = ""
    private var isReauth: Bool = false
    private var reauthAccountId: Int?
    
    // MARK: - Callbacks
    
    var onSuccess: (() -> Void)?
    var onExit: (() -> Void)?
    var onReady: ((Handler) -> Void)?
    
    // MARK: - Initialization
    
    init() {
        let client = AppAPIClient.live()
        self.plaidAPI = PlaidAPI(client: client)
    }
    
    init(plaidAPI: PlaidAPI) {
        self.plaidAPI = plaidAPI
    }
    
    // MARK: - Public Methods
    
    /// Opens Plaid Link to connect a new bank account
    func openLink(userId: String) {
        guard !userId.isEmpty else {
            errorMessage = "Please log in first."
            print("⚠️ [PlaidLink] No user ID provided")
            return
        }
        
        print("🔗 [PlaidLink] Opening link for user: \(userId)")
        
        currentUserId = userId
        isReauth = false
        reauthAccountId = nil
        isLoading = true
        errorMessage = nil
        
        _Concurrency.Task {
            do {
                print("🔗 [PlaidLink] Requesting link token...")
                let tokenResponse = try await plaidAPI.createLinkToken(userId: userId)
                print("✅ [PlaidLink] Got link token: \(tokenResponse.linkToken.prefix(30))...")
                
                await MainActor.run {
                    self.createHandler(with: tokenResponse.linkToken)
                }
                
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Failed to connect: \(error.localizedDescription)"
                    print("❌ [PlaidLink] Error: \(error)")
                }
            }
        }
    }
    
    /// Opens Plaid Link for reconnection
    func openLinkForReauth(accountId: Int, userId: String) {
        guard !userId.isEmpty else {
            errorMessage = "User ID is required"
            return
        }
        
        currentUserId = userId
        isReauth = true
        reauthAccountId = accountId
        isLoading = true
        errorMessage = nil
        
        _Concurrency.Task {
            do {
                let tokenResponse = try await plaidAPI.createReauthLinkToken(
                    connectedAccountId: accountId,
                    userId: userId
                )
                
                await MainActor.run {
                    self.createHandler(with: tokenResponse.linkToken)
                }
                
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Failed to reconnect: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// Get the handler to present
    func getHandler() -> Handler? {
        return linkHandler
    }
    
    /// Reset state
    func reset() {
        linkHandler = nil
        isLinkReady = false
        isLoading = false
    }
    
    // MARK: - Private Methods
    
    private func createHandler(with token: String) {
        print("🔧 [PlaidLink] Creating handler...")
        
        var configuration = LinkTokenConfiguration(token: token) { [weak self] success in
            guard let self = self else { return }
            print("✅ [PlaidLink] Success! Token: \(success.publicToken.prefix(20))...")
            
            let institutionName = success.metadata.institution.name
            
            _Concurrency.Task { @MainActor in
                await self.handleSuccess(
                    publicToken: success.publicToken,
                    institutionName: institutionName
                )
            }
        }
        
        configuration.onExit = { [weak self] (exit: LinkExit) in
            guard let self = self else { return }
            print("👋 [PlaidLink] User exited")
            
            _Concurrency.Task { @MainActor in
                self.handleExit(error: exit.error)
            }
        }
        
        configuration.onEvent = { (event: LinkEvent) in
            print("📊 [PlaidLink] Event: \(event.eventName)")
        }
        
        let result = Plaid.create(configuration)
        
        switch result {
        case .success(let handler):
            print("✅ [PlaidLink] Handler created, ready to present")
            self.linkHandler = handler
            self.isLoading = false
            self.isLinkReady = true
            self.onReady?(handler)
            
        case .failure(let error):
            print("❌ [PlaidLink] Failed to create handler: \(error)")
            self.isLoading = false
            self.errorMessage = "Failed to initialize: \(error.localizedDescription)"
        }
    }
    
    private func handleSuccess(publicToken: String, institutionName: String?) async {
        isLinkReady = false
        linkHandler = nil
        isLoading = true
        
        do {
            if isReauth, let accountId = reauthAccountId {
                _ = try await plaidAPI.completeReauth(
                    connectedAccountId: accountId,
                    userId: currentUserId
                )
                successMessage = "Account reconnected!"
            } else {
                let request = PlaidExchangeTokenRequestDTO(
                    publicToken: publicToken,
                    userId: currentUserId,
                    institutionName: institutionName
                )
                _ = try await plaidAPI.exchangePublicToken(request)
                successMessage = "Connected \(institutionName ?? "bank")!"
            }
            
            onSuccess?()
            
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    private func handleExit(error: ExitError?) {
        isLinkReady = false
        linkHandler = nil
        isLoading = false
        
        if let error = error {
            print("⚠️ [PlaidLink] Error: \(error.errorCode) - \(error.errorMessage)")
            errorMessage = error.displayMessage ?? error.errorMessage
        }
        
        onExit?()
    }
}

// MARK: - Plaid Link Presenter

struct PlaidLinkPresenter: UIViewControllerRepresentable {
    let handler: Handler
    
    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        vc.view.backgroundColor = .clear
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            handler.open(presentUsing: .viewController(vc))
        }
        
        return vc
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
