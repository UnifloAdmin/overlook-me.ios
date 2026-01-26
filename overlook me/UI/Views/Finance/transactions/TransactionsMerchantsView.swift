import SwiftUI

// MARK: - Transactions Merchants View

struct TransactionsMerchantsView: View {
    @SwiftUI.Environment(\.injected) private var container: DIContainer
    @Bindable var viewModel: TransactionsViewModel
    @State private var searchText = ""
    
    private var userId: String {
        container.appState.state.auth.user?.id ?? ""
    }
    
    private var filteredMerchants: [MerchantSummary] {
        if searchText.isEmpty {
            return viewModel.merchantSummaries
        }
        return viewModel.merchantSummaries.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var recurringMerchants: [MerchantSummary] {
        filteredMerchants.filter { $0.isRecurring }
    }
    
    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.merchantSummaries.isEmpty {
                ProgressView("Analyzing merchants...")
            } else if viewModel.merchantSummaries.isEmpty {
                ContentUnavailableView(
                    "No Merchants",
                    systemImage: "storefront",
                    description: Text("No merchant data available.")
                )
            } else {
                merchantsList
            }
        }
        .searchable(text: $searchText, prompt: "Search merchants")
    }
    
    private var merchantsList: some View {
        List {
            summarySection
            
            if !recurringMerchants.isEmpty {
                recurringSection
            }
            
            allMerchantsSection
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await viewModel.loadMerchants(userId: userId)
        }
    }
    
    // MARK: - Summary Section
    
    private var summarySection: some View {
        Section {
            Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                GridRow {
                    summaryCard(
                        icon: "storefront",
                        value: "\(viewModel.merchantSummaries.count)",
                        label: "Total Merchants"
                    )
                    
                    summaryCard(
                        icon: "repeat",
                        value: "\(recurringMerchants.count)",
                        label: "Recurring"
                    )
                }
                
                if let topMerchant = filteredMerchants.first {
                    GridRow {
                        summaryCard(
                            icon: "crown",
                            value: topMerchant.name,
                            label: formatCurrency(topMerchant.totalSpent + topMerchant.totalEarned)
                        )
                        .gridCellColumns(2)
                    }
                }
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }
    
    private func summaryCard(icon: String, value: String, label: String) -> some View {
        GroupBox {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.tint)
                
                Text(value)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Recurring Section
    
    private var recurringSection: some View {
        Section {
            ForEach(recurringMerchants.prefix(5)) { merchant in
                MerchantRow(merchant: merchant, showRecurringBadge: false)
            }
        } header: {
            Label("Recurring Merchants", systemImage: "repeat")
        } footer: {
            Text("Merchants with 3 or more transactions")
        }
    }
    
    // MARK: - All Merchants Section
    
    private var allMerchantsSection: some View {
        Section {
            ForEach(filteredMerchants) { merchant in
                MerchantRow(merchant: merchant, showRecurringBadge: true)
            }
        } header: {
            Label("All Merchants (\(filteredMerchants.count))", systemImage: "list.bullet")
        }
    }
    
    private func formatCurrency(_ value: Double) -> String {
        value.formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }
}

// MARK: - Merchant Row

private struct MerchantRow: View {
    let merchant: MerchantSummary
    let showRecurringBadge: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "storefront")
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(merchant.name)
                            .font(.body)
                            .lineLimit(1)
                        
                        if showRecurringBadge && merchant.isRecurring {
                            Label("Recurring", systemImage: "repeat")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Text("\(merchant.transactionCount) transactions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Spent")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(formatCurrency(merchant.totalSpent))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.red)
                }
                
                Spacer()
                
                VStack(alignment: .leading) {
                    Text("Earned")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(formatCurrency(merchant.totalEarned))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.green)
                }
                
                Spacer()
                
                VStack(alignment: .leading) {
                    Text("Average")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(formatCurrency(merchant.averageTransaction))
                        .font(.subheadline.monospacedDigit())
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Last")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(formatDate(merchant.lastTransactionDate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatCurrency(_ value: Double) -> String {
        value.formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }
    
    private func formatDate(_ date: Date) -> String {
        if date == .distantPast {
            return "—"
        }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}

#Preview {
    NavigationStack {
        TransactionsMerchantsView(viewModel: TransactionsViewModel())
    }
    .environment(\.injected, .previewAuthenticated)
}
