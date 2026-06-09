import SwiftUI

struct PlaceholderScreen: View {
    let title: String

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer().frame(height: 40)

                Image(systemName: "hammer.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Kalshi.textMuted)

                Text("Coming Soon")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Kalshi.textPrimary)

                Text("This feature is currently under development.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Kalshi.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer().frame(height: 40)
            }
            .frame(maxWidth: .infinity)
        }
        .scrollContentBackground(.hidden)
        .background(Kalshi.bg)
        .navigationTitle(title)
    }
}

