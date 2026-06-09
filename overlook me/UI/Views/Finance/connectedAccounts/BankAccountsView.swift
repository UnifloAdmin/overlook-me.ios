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
                HStack(spacing: 8) {
                    heroPill(label: "Active", value: "\(viewModel.activeAccountsCount)")
                    if viewModel.inactiveAccountsCount > 0 {
                        heroPill(label: "Attention", value: "\(viewModel.inactiveAccountsCount)")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 14)

                VStack(spacing: 12) {
                    if viewModel.isLoading || linkManager.isLoading {
                        loadingView
                    } else if viewModel.accounts.isEmpty {
                        emptyState
                    } else {
                        accountsList
                    }
                }
                .background(Color.kSurface)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.kSurface)
        .navigationTitle("Accounts")
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
        linkManager.openLink(userId: userId)
    }
    
    private func loadAccountsIfNeeded() {
        _Concurrency.Task {
            await viewModel.loadAccounts(userId: userId)
        }
    }
    
    // MARK: - Hero Pill

    private func heroPill(label: String, value: String) -> some View {
        Text("\(value)  \(label.uppercased())")
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .tracking(0.6)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.18))
                    .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 0.5))
            )
    }

    // MARK: - Accounts List
    
    private var accountsList: some View {
        VStack(spacing: 0) {
            Button(action: addAccount) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Link New")
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(-0.1)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.kPrimary, in: Capsule())
            }
            .buttonStyle(KPressButtonStyle())
            .frame(width: UIScreen.main.bounds.width * 0.54)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)

            VStack(spacing: 0) {
                ForEach(Array(viewModel.accounts.enumerated()), id: \.element.id) { index, account in
                    AccountRow(
                        account: account,
                        onReconnect: {
                            linkManager.openLinkForReauth(accountId: account.id, userId: userId)
                        }
                    )

                    if index < viewModel.accounts.count - 1 {
                        Rectangle()
                            .fill(Color.kBorder)
                            .frame(height: 1)
                            .padding(.horizontal, 16)
                    }
                }
            }

            Rectangle()
                .fill(Color.kBorder)
                .frame(height: 1)
                .padding(.horizontal, 16)
                .padding(.top, 16)

            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    KLabel("Total Balance")
                    Text(formatCurrency(viewModel.totalBalance))
                        .font(.system(size: 22, weight: .bold))
                        .tracking(-0.8)
                        .foregroundStyle(Color.kPrimary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .padding(.bottom, 100)
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 10) {
            ProgressView()
                .tint(Color.kSecondary)
            KLabel("Loading accounts…")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        KEmptyState(
            icon: "building.columns",
            title: "No Accounts Connected",
            message: "Link your bank accounts to automatically track balances and transactions.",
            ctaLabel: linkManager.isLoading ? "Opening…" : "Link Your First Account",
            ctaAction: addAccount
        )
        .padding(.horizontal, 16)
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
}

private extension Array where Element: Equatable {
    func uniqued() -> [Element] {
        reduce([]) { $0.contains($1) ? $0 : $0 + [$1] }
    }
}

// MARK: - Account Row

private struct AccountRow: View {
    let account: ConnectedAccountDTO
    let onReconnect: () -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 14) {
                    // Line 1 — logo · name · balance
                    HStack(spacing: 12) {
                        BankLogoView(institutionName: account.institutionName)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(account.institutionName)
                                .font(.system(size: 14, weight: .semibold))
                                .tracking(-0.3)
                                .foregroundStyle(Color.kPrimary)
                                .lineLimit(1)

                            if let subs = account.accounts, !subs.isEmpty {
                                let types = subs.compactMap { $0.subtype ?? $0.accountType }
                                    .map { $0.capitalized }
                                    .uniqued()
                                    .joined(separator: " · ")
                                if !types.isEmpty { KLabel(types) }
                            }
                        }

                        Spacer()

                        Text(formatCurrency(account.totalBalance))
                            .font(.system(size: 17, weight: .bold))
                            .tracking(-0.6)
                            .foregroundStyle(Color.kPrimary)
                            .monospacedDigit()

                        if let subs = account.accounts, subs.count > 1 {
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    isExpanded.toggle()
                                }
                            } label: {
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color.kTertiary)
                                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Line 2 — status + date chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            if account.isActive {
                                KStatusBadge(text: "Active", style: .done)
                            } else {
                                Button("Reconnect", action: onReconnect)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Color.kRed)
                                    .buttonStyle(.plain)
                            }
                            dateChip(icon: "link",                        label: "Connected", value: account.connectedAt)
                            dateChip(icon: "arrow.clockwise",             label: "Synced",    value: account.lastSyncedAt)
                            dateChip(icon: "dollarsign.arrow.circlepath", label: "Balance",   value: account.lastBalanceRefreshedAt)
                            dateChip(icon: "clock.arrow.circlepath",      label: "Next",      value: account.nextBalanceRefreshAt)
                        }
                    }
                }
                .padding(.leading, 16)
                .padding(.trailing, 16)
                .padding(.vertical, 22)
            }

            // Expanded sub-accounts
            if isExpanded, let subAccounts = account.accounts {
                Rectangle()
                    .fill(Color.kBorder)
                    .frame(height: 1)

                VStack(spacing: 0) {
                    ForEach(Array(subAccounts.enumerated()), id: \.element.id) { index, sub in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(sub.name ?? sub.accountName ?? "Account")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.kPrimary)
                                KLabel([sub.subtype?.capitalized, sub.lastFourDigits.map { "•• \($0)" }]
                                    .compactMap { $0 }.joined(separator: "  ·  "))
                            }
                            Spacer()
                            Text(formatCurrency(sub.currentBalance ?? sub.balance ?? 0))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.kPrimary)
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)

                        if index < subAccounts.count - 1 {
                            Rectangle()
                                .fill(Color.kBorder)
                                .frame(height: 1)
                                .padding(.horizontal, 20)
                        }
                    }
                }
                .background(Color.kDividerBg)
            }
        }
    }

    @ViewBuilder
    private func dateChip(icon: String, label: String, value: String?) -> some View {
        if let value {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .medium))
                Text("\(label) \(relativeTime(value))")
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(Color.kSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.kDividerBg, in: Capsule())
        }
    }

    private func relativeTime(_ isoString: String) -> String {
        guard let date = parseISO(isoString) else { return "—" }
        let rel = RelativeDateTimeFormatter()
        rel.unitsStyle = .abbreviated
        return rel.localizedString(for: date, relativeTo: Date())
    }

    private func parseISO(_ string: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: string) { return d }
        f.formatOptions = [.withInternetDateTime]
        if let d = f.date(from: string) { return d }
        // No timezone suffix — parse manually
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(identifier: "UTC")
        for fmt in ["yyyy-MM-dd'T'HH:mm:ss.SSSSSS", "yyyy-MM-dd'T'HH:mm:ss"] {
            df.dateFormat = fmt
            if let d = df.date(from: string) { return d }
        }
        return nil
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
        let name = institutionName.lowercased()
        if name.contains("chase") { return .blue }
        if name.contains("wells fargo") || name.contains("bank of america") { return .red }
        if name.contains("capital one") { return Color(red: 0.78, green: 0.18, blue: 0.18) }
        return Color.kSecondary
    }
    
    var body: some View {
        Image(systemName: "building.columns.fill")
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(iconColor)
            .frame(width: 36, height: 36)
            .background(Color.kDividerBg)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.kBorder, lineWidth: 1)
            )
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
