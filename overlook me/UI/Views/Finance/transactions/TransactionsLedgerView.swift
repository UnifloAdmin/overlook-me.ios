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
    }
    
    private var transactionsList: some View {
        List {
            ForEach(groupedTransactions.keys.sorted().reversed(), id: \.self) { date in
                Section {
                    ForEach(groupedTransactions[date] ?? []) { transaction in
                        TransactionRowView(transaction: transaction)
                    }
                } header: {
                    Text(formatSectionDate(date))
                }
            }
            
            Section {
                paginationFooter
            }
        }
        .listStyle(.insetGrouped)
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
        HStack {
            Button(action: { loadPreviousPage() }) {
                Label("Previous", systemImage: "chevron.left")
            }
            .disabled(viewModel.currentPage <= 1 || viewModel.isLoading)
            
            Spacer()
            
            VStack {
                Text("Page \(viewModel.currentPage) of \(viewModel.totalPages)")
                    .font(.caption)
                Text("\(viewModel.totalCount) transactions")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button(action: { loadNextPage() }) {
                HStack {
                    Text("Next")
                    Image(systemName: "chevron.right")
                }
            }
            .disabled(viewModel.currentPage >= viewModel.totalPages || viewModel.isLoading)
        }
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
        HStack(spacing: 12) {
            Image(systemName: transaction.isExpense ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .font(.title2)
                .foregroundColor(transaction.isExpense ? .red : .green)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.merchantName ?? transaction.name ?? "Unknown")
                    .font(.body)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    if let category = transaction.category {
                        Label(category, systemImage: "tag")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    if transaction.isPending == true {
                        Text("Pending")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(formattedAmount)
                    .font(.body.monospacedDigit().bold())
                    .foregroundColor(transaction.isExpense ? .primary : .green)
                
                Text(transaction.isExpense ? "Expense" : "Income")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
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
