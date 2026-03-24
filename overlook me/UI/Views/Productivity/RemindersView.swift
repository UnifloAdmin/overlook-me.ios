import SwiftUI

struct RemindersView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "bell.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.orange)
            Text("Reminders")
                .font(.title2.weight(.semibold))
            Text("Reminders coming soon.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        RemindersView()
    }
}
