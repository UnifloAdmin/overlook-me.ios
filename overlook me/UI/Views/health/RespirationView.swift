import SwiftUI

struct RespirationView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "lungs.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.mint)
            Text("Respiration")
                .font(.title2.weight(.semibold))
            Text("Respiration tracking coming soon.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .navigationTitle("Respiration")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        RespirationView()
    }
}
