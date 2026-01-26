import SwiftUI

struct TrendsView: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("Balance History")
                        .font(.headline)
                    Text("Coming soon")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
            }
            
            Section("Insights") {
                Label("Net worth increased 12% this month", systemImage: "arrow.up.right")
                    .foregroundStyle(.green)
                
                Label("Savings rate: 24%", systemImage: "leaf.fill")
                    .foregroundStyle(.green)
                
                Label("3 recurring payments detected", systemImage: "repeat")
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Trends")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        TrendsView()
    }
}
