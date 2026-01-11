import SwiftUI

struct HabitsAnalyticsView: View {
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(.secondary)
            
            Text("Analytics coming soon")
                .font(.title2.weight(.semibold))
            
            Text("Track momentum, streaks, and insights across all of your habits.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        HabitsAnalyticsView()
    }
}
