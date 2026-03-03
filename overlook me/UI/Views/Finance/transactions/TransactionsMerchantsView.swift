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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .background(Color(.systemGroupedBackground))
        .searchable(text: $searchText, prompt: "Search merchants")
    }
    
    private var merchantsList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                summarySection
                
                if !recurringMerchants.isEmpty {
                    recurringSection
                }
                
                allMerchantsSection
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .refreshable {
            await viewModel.loadMerchants(userId: userId)
        }
    }
    
    // MARK: - Summary Section
    
    private var summarySection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                summaryCard(
                    icon: "storefront.fill",
                    value: "\(viewModel.merchantSummaries.count)",
                    label: "Total Merchants",
                    tint: .blue
                )
                
                summaryCard(
                    icon: "repeat.circle.fill",
                    value: "\(recurringMerchants.count)",
                    label: "Recurring",
                    tint: .purple
                )
            }
            
            if let topMerchant = filteredMerchants.first {
                topMerchantCard(merchant: topMerchant)
            }
        }
    }
    
    private func summaryCard(icon: String, value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(tint)
            
            Text(value)
                .font(.title3.bold())
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private func topMerchantCard(merchant: MerchantSummary) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(.yellow.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: "crown.fill")
                    .font(.title3)
                    .foregroundStyle(.yellow)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Top Merchant")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(merchant.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(formatCurrency(merchant.totalSpent + merchant.totalEarned))
                .font(.subheadline.monospacedDigit().weight(.semibold))
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Recurring Section
    
    private var recurringSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "repeat.circle.fill")
                    .foregroundStyle(.purple)
                Text("Recurring Merchants")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }
            .padding(.horizontal, 4)
            
            VStack(spacing: 8) {
                ForEach(recurringMerchants.prefix(5)) { merchant in
                    MerchantRow(merchant: merchant, showRecurringBadge: false)
                }
            }
            
            Text("Merchants with 3+ transactions")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 4)
        }
    }
    
    // MARK: - All Merchants Section
    
    private var allMerchantsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "list.bullet.circle.fill")
                    .foregroundStyle(.tint)
                Text("All Merchants")
                    .font(.subheadline.weight(.semibold))
                Text("(\(filteredMerchants.count))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 4)
            
            VStack(spacing: 8) {
                ForEach(filteredMerchants) { merchant in
                    MerchantRow(merchant: merchant, showRecurringBadge: true)
                }
            }
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
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(.tint.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "storefront.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.tint)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(merchant.name)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                        
                        if showRecurringBadge && merchant.isRecurring {
                            Image(systemName: "repeat")
                                .font(.caption2)
                                .foregroundStyle(.purple)
                                .padding(4)
                                .background(.purple.opacity(0.12), in: Circle())
                        }
                    }
                    
                    Text("\(merchant.transactionCount) transactions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            // Stats row
            HStack(spacing: 0) {
                statColumn(label: "Spent", value: formatCurrency(merchant.totalSpent), color: .red)
                Spacer()
                statColumn(label: "Earned", value: formatCurrency(merchant.totalEarned), color: .green)
                Spacer()
                statColumn(label: "Average", value: formatCurrency(merchant.averageTransaction), color: .primary)
                Spacer()
                statColumn(label: "Last", value: formatDate(merchant.lastTransactionDate), color: .secondary, alignment: .trailing)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
    
    private func statColumn(label: String, value: String, color: Color, alignment: HorizontalAlignment = .leading) -> some View {
        VStack(alignment: alignment, spacing: 3) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.caption.monospacedDigit().weight(.medium))
                .foregroundStyle(color)
        }
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
