import SwiftUI
import Combine
import Foundation
import LinkKit

// MARK: - Bank Accounts View

struct BankAccountsView: View {
    @SwiftUI.Environment(\.injected) private var container: DIContainer
    @StateObject private var viewModel = BankAccountsViewModel()
    @StateObject private var linkManager = PlaidLinkManager()
    @State private var showPlaidLink = false
    @State private var plaidHandler: Handler?
    
    init() {}
    
    private var userId: String {
        container.appState.state.auth.user?.id ?? ""
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                summaryHeader
                
                if viewModel.isLoading || linkManager.isLoading {
                    loadingView
                } else if viewModel.accounts.isEmpty {
                    emptyState
                } else {
                    accountsList
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Accounts")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: addAccount) {
                    if linkManager.isLoading {
                        ProgressView()
                    } else {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                }
                .disabled(linkManager.isLoading)
            }
        }
        .onAppear {
            setupLinkCallbacks()
            loadAccountsIfNeeded()
        }
        .fullScreenCover(isPresented: $showPlaidLink) {
            if let handler = plaidHandler {
                PlaidLinkPresenter(handler: handler)
                    .ignoresSafeArea()
                    .onDisappear {
                        linkManager.reset()
                        plaidHandler = nil
                        loadAccountsIfNeeded()
                    }
            }
        }
        .alert(isPresented: Binding(
            get: { viewModel.errorMessage != nil || linkManager.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil; linkManager.errorMessage = nil } }
        )) {
            Alert(
                title: Text("Error"),
                message: Text(viewModel.errorMessage ?? linkManager.errorMessage ?? ""),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func setupLinkCallbacks() {
        linkManager.onSuccess = {
            showPlaidLink = false
            plaidHandler = nil
            loadAccountsIfNeeded()
        }
        
        linkManager.onExit = {
            showPlaidLink = false
            plaidHandler = nil
        }
        
        linkManager.onReady = { handler in
            plaidHandler = handler
            showPlaidLink = true
        }
    }
    
    private func addAccount() {
        print("🔘 [BankAccountsView] Add account tapped, userId: \(userId)")
        linkManager.openLink(userId: userId)
    }
    
    private func loadAccountsIfNeeded() {
        _Concurrency.Task {
            await viewModel.loadAccounts(userId: userId)
        }
    }
    
    // MARK: - Summary Header
    
    private var summaryHeader: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("Total Balance")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(formatCurrency(viewModel.totalBalance))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                
                HStack(spacing: 16) {
                    Label("\(viewModel.activeAccountsCount) Active", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    if viewModel.inactiveAccountsCount > 0 {
                        Label("\(viewModel.inactiveAccountsCount) Needs Attention", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .padding(.horizontal, 20)
            .background(Color(.systemBackground).opacity(0.8))
            .cornerRadius(20)
        }
        .padding()
    }
    
    // MARK: - Accounts List
    
    private var accountsList: some View {
        LazyVStack(spacing: 12) {
            ForEach(viewModel.accounts) { account in
                AccountCard(
                    account: account,
                    onReconnect: {
                        linkManager.openLinkForReauth(accountId: account.id, userId: userId)
                    }
                )
            }
            
            addAccountButton
        }
        .padding(.horizontal)
        .padding(.bottom, 100)
    }
    
    private var addAccountButton: some View {
        Button(action: addAccount) {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                
                Text("Link New Account")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground).opacity(0.8))
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading accounts...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.accentColor)
            }
            
            VStack(spacing: 8) {
                Text("No Accounts Connected")
                    .font(.title2.bold())
                
                Text("Link your bank accounts to automatically track balances and transactions.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Button(action: addAccount) {
                HStack {
                    if linkManager.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    Label(linkManager.isLoading ? "Opening..." : "Link Your First Account", systemImage: "link")
                        .font(.headline)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(linkManager.isLoading)
        }
        .padding(.vertical, 60)
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
}

// MARK: - Account Card

private struct AccountCard: View {
    let account: ConnectedAccountDTO
    let onReconnect: () -> Void
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                HStack(spacing: 14) {
                    BankLogoView(institutionName: account.institutionName)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(account.institutionName)
                            .font(.headline)
                        
                        if let firstAccount = account.accounts?.first,
                           let lastFour = firstAccount.lastFourDigits {
                            Text("••\(lastFour)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    statusBadge
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Balance")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(formatCurrency(account.totalBalance))
                            .font(.title2.bold().monospacedDigit())
                    }
                    
                    Spacer()
                    
                    if let subAccounts = account.accounts, subAccounts.count > 1 {
                        Button(action: {
                            withAnimation(.spring()) {
                                isExpanded.toggle()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Text("\(subAccounts.count) accounts")
                                    .font(.caption)
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            }
                            .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                if isExpanded, let subAccounts = account.accounts {
                    Divider()
                    
                    VStack(spacing: 10) {
                        ForEach(subAccounts) { subAccount in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(subAccount.name ?? subAccount.accountName ?? "Account")
                                        .font(.subheadline)
                                    
                                    if let type = subAccount.accountType {
                                        Text(type.capitalized)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                Text(formatCurrency(subAccount.currentBalance ?? subAccount.balance ?? 0))
                                    .font(.subheadline.monospacedDigit())
                            }
                        }
                    }
                }
                
                HStack {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text("Connected \(formatDate(account.connectedAt))")
                        .font(.caption)
                    
                    Spacer()
                    
                    if !account.isActive {
                        Button("Reconnect", action: onReconnect)
                            .font(.caption.bold())
                            .foregroundColor(.orange)
                    }
                }
                .foregroundColor(.secondary)
            }
            .padding()
        }
        .background(Color(.systemBackground).opacity(0.8))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(account.isActive ? Color.clear : Color.orange.opacity(0.5), lineWidth: 1)
        )
    }
    
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(account.isActive ? Color.green : Color.orange)
                .frame(width: 6, height: 6)
            
            Text(account.isActive ? "Active" : "Error")
                .font(.caption2.bold())
                .foregroundColor(account.isActive ? .green : .orange)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            (account.isActive ? Color.green : Color.orange).opacity(0.1)
        )
        .clipShape(Capsule())
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            return displayFormatter.string(from: date)
        }
        
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            return displayFormatter.string(from: date)
        }
        
        return dateString
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
}

// MARK: - Bank Logo View

private struct BankLogoView: View {
    let institutionName: String
    
    private var iconColor: Color {
        switch institutionName.lowercased() {
        case let name where name.contains("chase"):
            return .blue
        case let name where name.contains("wells fargo"):
            return .red
        case let name where name.contains("bank of america"):
            return .red
        case let name where name.contains("capital one"):
            return .orange
        default:
            return .teal
        }
    }
    
    var body: some View {
        Image(systemName: "building.columns.fill")
            .font(.title2)
            .foregroundColor(iconColor)
            .frame(width: 44, height: 44)
            .background(iconColor.opacity(0.1))
            .cornerRadius(12)
    }
}

// MARK: - View Model

@MainActor
final class BankAccountsViewModel: ObservableObject {
    @Published var accounts: [ConnectedAccountDTO] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    var totalBalance: Double {
        accounts.filter(\.isActive).reduce(0) { $0 + $1.totalBalance }
    }
    
    var activeAccountsCount: Int {
        accounts.filter(\.isActive).count
    }
    
    var inactiveAccountsCount: Int {
        accounts.filter { !$0.isActive }.count
    }
    
    func loadAccounts(userId: String) async {
        guard !userId.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let client = AppAPIClient.live()
            let api = PlaidAPI(client: client)
            let response = try await api.getConnectedAccounts(userId: userId)
            accounts = response.accounts
        } catch {
            errorMessage = "Failed to load accounts: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        BankAccountsView()
    }
    .environment(\.injected, .previewAuthenticated)
}
