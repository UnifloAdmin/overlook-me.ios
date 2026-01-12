import SwiftUI

struct FinancesView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
            
            Text("Finances")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Monitor spending, budgets, and financial health.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .navigationTitle("Finances")
    }
}

#Preview {
    FinancesView()
}
