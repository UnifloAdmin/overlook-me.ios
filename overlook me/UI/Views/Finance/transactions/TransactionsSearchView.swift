import SwiftUI

// MARK: - Transactions Search View

struct TransactionsSearchView: View {
    @SwiftUI.Environment(\.injected) private var container: DIContainer
    @Bindable var viewModel: TransactionsViewModel
    
    @State private var showAdvanced = false
    @State private var showSaved = false
    @State private var showSaveDialog = false
    @State private var newFilterName = ""
    
    private var userId: String {
        container.appState.state.auth.user?.id ?? ""
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                searchHeader
                
                KSearchField(
                    placeholder: "Search by name, merchant, category...",
                    text: $viewModel.searchFilters.searchText,
                    onCommit: { performSearch() }
                )
                .onChange(of: viewModel.searchFilters.searchText) { _, _ in
                    _Concurrency.Task {
                        try? await _Concurrency.Task.sleep(for: .milliseconds(300))
                        performSearch()
                    }
                }
                
                basicFiltersSection
                advancedFiltersSection
                
                if !viewModel.savedFilters.isEmpty {
                    savedFiltersSection
                }
                
                resultsSummary
                
                if !viewModel.searchResults.isEmpty {
                    resultsList
                } else if !viewModel.isSearchLoading {
                    emptyState
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        }
        .background(Color.kSurface)
        .task {
            viewModel.loadPersistedFilters()
            await viewModel.loadCategories(userId: userId)
        }
        .sheet(isPresented: $showSaveDialog) {
            saveFilterSheet
        }
    }
    
    // MARK: - Header
    
    private var searchHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Advanced Search")
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(-0.3)
                    .foregroundStyle(Color.kPrimary)
                KLabel("Multi-criteria filtering")
            }
            
            Spacer()
            
            let activeCount = activeFiltersCount
            if activeCount > 0 {
                HStack(spacing: 6) {
                    Button {
                        viewModel.clearSearchFilters()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                            Text("CLEAR (\(activeCount))")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(0.6)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .foregroundStyle(Color.kRed)
                        .background(Color.kRedBg, in: Capsule())
                    }
                    .buttonStyle(KPressButtonStyle())
                    
                    Button {
                        showSaveDialog = true
                    } label: {
                        Image(systemName: "bookmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.kSecondary)
                            .frame(width: 26, height: 26)
                            .background(Color.kSurface, in: Circle())
                            .overlay(Circle().stroke(Color.kBorderMedium, lineWidth: 1))
                    }
                    .buttonStyle(KPressButtonStyle())
                }
            }
        }
    }
    
    // MARK: - Basic Filters
    
    private var basicFiltersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Transaction type inline pills
            HStack(spacing: 5) {
                KLabel("Type")
                    .frame(width: 30)
                
                ForEach(["all", "expense", "income"], id: \.self) { type in
                    let isActive = viewModel.searchFilters.transactionType == type
                    Button {
                        viewModel.searchFilters.transactionType = type
                        performSearch()
                    } label: {
                        Text(type == "all" ? "ALL" : type.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(0.6)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 5)
                            .foregroundStyle(isActive ? Color.white : Color.kTertiary)
                            .background(isActive ? Color.kPrimary : Color.kSurface, in: Capsule())
                            .overlay(isActive ? nil : Capsule().stroke(Color.kBorderMedium, lineWidth: 1))
                    }
                    .buttonStyle(KPressButtonStyle())
                }
                
                Spacer()
                
                // Category picker inline
                Picker("", selection: $viewModel.searchFilters.category) {
                    Text("All").tag("all")
                    ForEach(viewModel.categories, id: \.self) { cat in
                        Text(cat).tag(cat)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .tint(Color.kSecondary)
                .onChange(of: viewModel.searchFilters.category) { _, _ in performSearch() }
            }
            
            // Date range inline
            HStack(spacing: 8) {
                KLabel("From")
                DatePicker("", selection: $viewModel.searchFilters.startDate, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .onChange(of: viewModel.searchFilters.startDate) { _, _ in performSearch() }
                
                Text("–")
                    .foregroundStyle(Color.kTertiary)
                    .font(.system(size: 12))
                
                KLabel("To")
                DatePicker("", selection: $viewModel.searchFilters.endDate, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .onChange(of: viewModel.searchFilters.endDate) { _, _ in performSearch() }
            }
        }
        .padding(12)
        .background(Color.kSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.kBorder, lineWidth: 1))
    }
    
    // MARK: - Advanced Filters
    
    private var advancedFiltersSection: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.1)) {
                    showAdvanced.toggle()
                }
            } label: {
                HStack(spacing: 5) {
                    KLabel("Advanced Filters")
                    Spacer()
                    Image(systemName: showAdvanced ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Color.kTertiary)
                }
            }
            .buttonStyle(.plain)
            
            if showAdvanced {
                VStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        KLabel("Merchant Name")
                        KSearchField(
                            placeholder: "Filter by merchant...",
                            text: $viewModel.searchFilters.merchantName,
                            onCommit: { performSearch() }
                        )
                        .onChange(of: viewModel.searchFilters.merchantName) { _, _ in performSearch() }
                    }
                    
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            KLabel("Min Amount")
                            HStack(spacing: 3) {
                                Text("$")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.kTertiary)
                                TextField("0", value: $viewModel.searchFilters.minAmount, format: .number)
                                    .font(.system(size: 13, weight: .medium))
                                    .padding(8)
                                    .background(Color.kInputBg, in: RoundedRectangle(cornerRadius: 8))
                                    .keyboardType(.decimalPad)
                                    .onChange(of: viewModel.searchFilters.minAmount) { _, _ in performSearch() }
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 3) {
                            KLabel("Max Amount")
                            HStack(spacing: 3) {
                                Text("$")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.kTertiary)
                                TextField("0", value: $viewModel.searchFilters.maxAmount, format: .number)
                                    .font(.system(size: 13, weight: .medium))
                                    .padding(8)
                                    .background(Color.kInputBg, in: RoundedRectangle(cornerRadius: 8))
                                    .keyboardType(.decimalPad)
                                    .onChange(of: viewModel.searchFilters.maxAmount) { _, _ in performSearch() }
                            }
                        }
                    }
                }
                .padding(.top, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(Color.kSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.kBorder, lineWidth: 1))
    }
    
    // MARK: - Saved Filters
    
    private var savedFiltersSection: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.1)) {
                    showSaved.toggle()
                }
            } label: {
                HStack(spacing: 5) {
                    KLabel("Saved Filters (\(viewModel.savedFilters.count))")
                    Spacer()
                    Image(systemName: showSaved ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Color.kTertiary)
                }
            }
            .buttonStyle(.plain)
            
            if showSaved {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.savedFilters.enumerated()), id: \.element.id) { index, filter in
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(filter.name)
                                    .font(.system(size: 12, weight: .semibold))
                                    .tracking(-0.1)
                                    .foregroundStyle(Color.kPrimary)
                                Text(filter.createdAt.formatted(.dateTime.month(.abbreviated).day().year()))
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(Color.kTertiary)
                            }
                            
                            Spacer()
                            
                            Button {
                                viewModel.loadSavedFilter(filter)
                                performSearch()
                            } label: {
                                Text("APPLY")
                                    .font(.system(size: 10, weight: .bold))
                                    .tracking(0.6)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4)
                                    .background(Color.kPrimary, in: Capsule())
                            }
                            .buttonStyle(KPressButtonStyle())
                            
                            Button {
                                viewModel.deleteSavedFilter(id: filter.id)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.kRed)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 6)
                        
                        if index < viewModel.savedFilters.count - 1 {
                            Rectangle().fill(Color.kBorder).frame(height: 1)
                        }
                    }
                }
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(Color.kSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.kBorder, lineWidth: 1))
    }
    
    // MARK: - Results Summary
    
    private var resultsSummary: some View {
        HStack(spacing: 8) {
            Text("\(viewModel.searchResults.count)")
                .font(.system(size: 20, weight: .bold))
                .tracking(-0.5)
                .foregroundStyle(Color.kPrimary)
            
            KLabel("transactions")
            
            if activeFiltersCount > 0 {
                KStatusBadge(text: "\(activeFiltersCount) filters", style: .pending)
            }
            
            Spacer()
            
            if !viewModel.searchResults.isEmpty {
                let income = viewModel.searchResults.filter(\.isIncome).reduce(0.0) { $0 + $1.displayAmount }
                let expenses = viewModel.searchResults.filter(\.isExpense).reduce(0.0) { $0 + $1.displayAmount }
                
                HStack(spacing: 6) {
                    Text("+\(formatCurrency(income))")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(-0.1)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.kGreen, in: Capsule())
                    
                    Text("-\(formatCurrency(expenses))")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(-0.1)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.kRed, in: Capsule())
                }
            }
        }
        .padding(.vertical, 6)
    }
    
    // MARK: - Results List
    
    private var resultsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.searchResults.enumerated()), id: \.element.id) { index, txn in
                searchResultRow(txn: txn)
                
                if index < viewModel.searchResults.count - 1 {
                    Rectangle().fill(Color.kBorder).frame(height: 1)
                }
            }
            
            if viewModel.searchTotalPages > 1 {
                HStack(spacing: 14) {
                    KPill(label: "Prev", icon: "chevron.left", isActive: false) {
                        if viewModel.searchPage > 1 {
                            viewModel.searchPage -= 1
                            performSearch()
                        }
                    }
                    .opacity(viewModel.searchPage <= 1 ? 0.4 : 1)
                    
                    KLabel("Page \(viewModel.searchPage) of \(viewModel.searchTotalPages)")
                    
                    KPill(label: "Next", icon: "chevron.right", isActive: false) {
                        if viewModel.searchPage < viewModel.searchTotalPages {
                            viewModel.searchPage += 1
                            performSearch()
                        }
                    }
                    .opacity(viewModel.searchPage >= viewModel.searchTotalPages ? 0.4 : 1)
                }
                .padding(.vertical, 12)
            }
        }
        .background(Color.kSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.kBorder, lineWidth: 1))
    }
    
    private func searchResultRow(txn: TransactionDTO) -> some View {
        HStack(spacing: 10) {
            // Smaller direction icon — neutral styling
            ZStack {
                Circle()
                    .fill(Color.kDividerBg)
                    .frame(width: 28, height: 28)
                Image(systemName: txn.isExpense ? "arrow.up.right" : "arrow.down.left")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.kSecondary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(txn.merchantName ?? txn.name ?? "Unknown")
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(-0.2)
                        .foregroundStyle(Color.kPrimary)
                        .lineLimit(1)
                    
                    if txn.isPending == true {
                        KStatusBadge(text: "P", style: .pending)
                    }
                }
                
                HStack(spacing: 6) {
                    Text(formatShortDate(txn.date))
                        .font(.system(size: 10, weight: .medium))
                        .tracking(0.2)
                        .foregroundStyle(Color.kTertiary)
                    
                    if let category = txn.category {
                        Text(category)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.kSecondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.kDividerBg, in: Capsule())
                    }
                }
            }
            
            Spacer()
            
            Text("\(txn.isIncome ? "+" : "-")\(formatCurrency(txn.displayAmount))")
                .font(.system(size: 13, weight: .bold))
                .tracking(-0.2)
                .foregroundStyle(txn.isIncome ? Color.kGreen : Color.kPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        KEmptyState(
            icon: "magnifyingglass",
            title: "No transactions found",
            message: "Adjust your filters to see more results",
            ctaLabel: activeFiltersCount > 0 ? "Clear All Filters" : nil,
            ctaAction: { viewModel.clearSearchFilters() }
        )
    }
    
    // MARK: - Save Filter Sheet
    
    private var saveFilterSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    KLabel("Filter Name")
                    TextField("e.g., Monthly Groceries", text: $newFilterName)
                        .font(.system(size: 13, weight: .medium))
                        .padding(10)
                        .background(Color.kInputBg, in: RoundedRectangle(cornerRadius: 10))
                }
                
                Spacer()
            }
            .padding(14)
            .background(Color.kSurface)
            .navigationTitle("Save Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showSaveDialog = false
                        newFilterName = ""
                    }
                    .foregroundStyle(Color.kSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.saveFilter(name: newFilterName)
                        showSaveDialog = false
                        newFilterName = ""
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.kPrimary)
                    .disabled(newFilterName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Helpers
    
    private var activeFiltersCount: Int {
        var count = 0
        if !viewModel.searchFilters.searchText.isEmpty { count += 1 }
        if viewModel.searchFilters.transactionType != "all" { count += 1 }
        if viewModel.searchFilters.category != "all" { count += 1 }
        if viewModel.searchFilters.minAmount != nil { count += 1 }
        if viewModel.searchFilters.maxAmount != nil { count += 1 }
        if !viewModel.searchFilters.merchantName.isEmpty { count += 1 }
        return count
    }
    
    private func performSearch() {
        let uid = userId
        let vm = viewModel
        _Concurrency.Task {
            await vm.executeSearch(userId: uid)
        }
    }
    
    private func formatCurrency(_ value: Double) -> String {
        abs(value).formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }
    
    private func formatShortDate(_ dateString: String) -> String {
        let date = viewModel.parseDate(dateString)
        if date == .distantPast { return "—" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}

#Preview {
    NavigationStack {
        TransactionsSearchView(viewModel: TransactionsViewModel())
    }
    .environment(\.injected, .previewAuthenticated)
}
