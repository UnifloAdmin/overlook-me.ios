import SwiftUI

struct MobilityView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "figure.walk")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.green)
            Text("Mobility")
                .font(.title2.weight(.semibold))
            Text("Mobility tracking coming soon.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .navigationTitle("Mobility")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        MobilityView()
    }
}
