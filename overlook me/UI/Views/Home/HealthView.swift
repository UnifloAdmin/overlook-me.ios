import SwiftUI

struct HealthView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.pink)
            
            Text("Health")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Review wellness habits, recovery stats, and insights.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .navigationTitle("Health")
    }
}

#Preview {
    HealthView()
}
