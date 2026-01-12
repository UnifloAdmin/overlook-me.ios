import SwiftUI

struct FocusView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 64))
                .foregroundColor(.blue)
            
            Text("Focus")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Track tasks and stay on top of your priorities.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .navigationTitle("Focus")
    }
}

#Preview {
    FocusView()
}
