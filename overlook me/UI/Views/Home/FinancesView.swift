import SwiftUI

struct FinancesView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(Kalshi.textMuted)

            Text("Finances")
                .font(.system(size: 20, weight: .semibold))
                .tracking(-0.28)
                .foregroundStyle(Kalshi.textPrimary)

            Text("Monitor spending, budgets, and financial health.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Kalshi.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
        .background(Kalshi.bg)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(red: 0.820, green: 0.835, blue: 0.855), lineWidth: 1) // #d1d5db
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .navigationTitle("Finances")
    }
}

#Preview {
    FinancesView()
}
