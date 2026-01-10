import SwiftUI

struct PlaceholderScreen: View {
    let title: String
    var subtitle: String? = nil
    
    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.title2.weight(.semibold))
            
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

