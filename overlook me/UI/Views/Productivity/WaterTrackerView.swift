import SwiftUI

struct WaterTrackerView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "drop.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.blue)
            Text("Water")
                .font(.title2.weight(.semibold))
            Text("Water tracking coming soon.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .navigationTitle("Water")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        WaterTrackerView()
    }
}
