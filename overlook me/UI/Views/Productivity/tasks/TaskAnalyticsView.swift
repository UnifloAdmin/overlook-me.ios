import SwiftUI

struct TaskAnalyticsView: View {
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            gradientLayer
            
            ScrollView {
                VStack(spacing: 16) {
                    Text("Analytics")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.primary)
                        .padding(.top, 60)
                    
                    Text("Coming Soon")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
        .ignoresSafeArea(edges: .top)
    }
    
    @ViewBuilder
    private var gradientLayer: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [
                    Color.orange.opacity(0.3),
                    Color.pink.opacity(0.2),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 200)
            Spacer()
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}
