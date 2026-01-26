import SwiftUI

struct BudgetsTile: View {
    let budgets: [Budget]
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                Label("Budgets", systemImage: "dollarsign.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                
                VStack(spacing: 12) {
                    ForEach(budgets.prefix(3)) { budget in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(budget.name)
                                    .font(.subheadline)
                                
                                Spacer()
                                
                                Text(budget.isOverBudget ? "$\(Int(budget.spent - budget.limit)) over" : "$\(Int(budget.remaining)) left")
                                    .font(.caption)
                                    .foregroundStyle(budget.isOverBudget ? .primary : .secondary)
                            }
                            
                            ProgressView(value: budget.progress)
                                .tint(budget.isOverBudget ? .red : (budget.progress > 0.8 ? .orange : .indigo))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .glassTile()
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    BudgetsTile(
        budgets: [
            Budget(name: "Groceries", limit: 500, spent: 387, category: "food"),
            Budget(name: "Entertainment", limit: 200, spent: 156, category: "fun"),
            Budget(name: "Transport", limit: 150, spent: 178, category: "transport")
        ],
        onTap: {}
    )
    .frame(height: 180)
    .padding()
}
