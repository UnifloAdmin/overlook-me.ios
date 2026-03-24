import SwiftUI

struct ExerciseView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.orange)
            Text("Exercise")
                .font(.title2.weight(.semibold))
            Text("Exercise tracking coming soon.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .navigationTitle("Exercise")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        ExerciseView()
    }
}
