import SwiftUI

struct HeartView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "heart.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.red)
            Text("Heart")
                .font(.title2.weight(.semibold))
            Text("Heart rate tracking coming soon.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .navigationTitle("Heart")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        HeartView()
    }
}
