import SwiftUI

// MARK: - Native iOS Tile Style

extension View {
    func glassTile(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
