import SwiftUI

struct ChallengesDashboardView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "flag.2.crossed")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(.secondary)
            
            Text("Challenges coming soon")
                .font(.title2.weight(.semibold))
            
            Text("Create community goals and friendly competitions to keep habits fun.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Challenges")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ChallengesDashboardView()
    }
}
