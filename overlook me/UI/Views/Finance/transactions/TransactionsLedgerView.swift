import SwiftUI

// MARK: - Transactions Ledger View

struct TransactionsLedgerView: View {
    @SwiftUI.Environment(\.injected) private var container: DIContainer
    @Bindable var viewModel: TransactionsViewModel
    
    private var userId: String {
        container.appState.state.auth.user?.id ?? ""
    }
    
    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.transactions.isEmpty {
                ProgressView("Loading transactions...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.transactions.isEmpty {
                ContentUnavailableView(
                    "No Transactions",
                    systemImage: "doc.text",
                    description: Text("No transactions found for the selected time range.")
                )
            } else {
                transactionsList
            }
        }
        .background(Color(.systemGroupedBackground))
    }
    
    private var transactionsList: some View {
        List {
            ForEach(groupedTransactions.keys.sorted().reversed(), id: \.self) { date in
                Section {
                    ForEach(groupedTransactions[date] ?? []) { transaction in
                        TransactionRowView(transaction: transaction)
                            .listRowBackground(Color.clear)
                    }
                } header: {
                    Text(formatSectionDate(date))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .textCase(nil)
                }
            }
            
            Section {
                paginationFooter
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable {
            await viewModel.loadTransactions(userId: userId)
        }
    }
    
    private var groupedTransactions: [String: [TransactionDTO]] {
        Dictionary(grouping: viewModel.transactions) { transaction in
            String(transaction.date.prefix(10))
        }
    }
    
    private var paginationFooter: some View {
        HStack(spacing: 16) {
            Button(action: { loadPreviousPage() }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left.circle.fill")
                    Text("Previous")
                }
                .font(.subheadline.weight(.medium))
            }
            .disabled(viewModel.currentPage <= 1 || viewModel.isLoading)
            .opacity(viewModel.currentPage <= 1 ? 0.4 : 1)
            
            Spacer()
            
            VStack(spacing: 2) {
                Text("Page \(viewModel.currentPage) of \(viewModel.totalPages)")
                    .font(.caption.weight(.medium))
                Text("\(viewModel.totalCount) transactions")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            
            Spacer()
            
            Button(action: { loadNextPage() }) {
                HStack(spacing: 6) {
                    Text("Next")
                    Image(systemName: "chevron.right.circle.fill")
                }
                .font(.subheadline.weight(.medium))
            }
            .disabled(viewModel.currentPage >= viewModel.totalPages || viewModel.isLoading)
            .opacity(viewModel.currentPage >= viewModel.totalPages ? 0.4 : 1)
        }
        .padding(.vertical, 12)
    }
    
    private func loadPreviousPage() {
        let page = viewModel.currentPage - 1
        let uid = userId
        let vm = viewModel
        _Concurrency.Task {
            await vm.loadTransactions(userId: uid, page: page)
        }
    }
    
    private func loadNextPage() {
        let page = viewModel.currentPage + 1
        let uid = userId
        let vm = viewModel
        _Concurrency.Task {
            await vm.loadTransactions(userId: uid, page: page)
        }
    }
    
    private func formatSectionDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        guard let date = formatter.date(from: dateString) else { return dateString }
        
        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        }
    }
}

// MARK: - Transaction Row View

private struct TransactionRowView: View {
    let transaction: TransactionDTO
    
    var body: some View {
        HStack(spacing: 14) {
            // Icon with glass background
            ZStack {
                Circle()
                    .fill(transaction.isExpense ? Color.red.opacity(0.12) : Color.green.opacity(0.12))
                    .frame(width: 44, height: 44)
                
                Image(systemName: transaction.isExpense ? "arrow.up.right" : "arrow.down.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(transaction.isExpense ? .red : .green)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.merchantName ?? transaction.name ?? "Unknown")
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    if let category = transaction.category {
                        Text(category)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.quaternary, in: Capsule())
                    }
                    
                    if transaction.isPending == true {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(.orange)
                                .frame(width: 5, height: 5)
                            Text("Pending")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(formattedAmount)
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundColor(transaction.isExpense ? .primary : .green)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
    
    private var formattedAmount: String {
        let prefix = transaction.isExpense ? "-" : "+"
        let code = transaction.isoCurrencyCode ?? "USD"
        return prefix + transaction.displayAmount.formatted(.currency(code: code))
    }
}

#Preview {
    NavigationStack {
        TransactionsLedgerView(viewModel: TransactionsViewModel())
    }
    .environment(\.injected, .previewAuthenticated)
}
