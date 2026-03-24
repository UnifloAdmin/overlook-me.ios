import SwiftUI
import UIKit

// MARK: - Kalshi Adaptive Color Tokens
// Each token resolves to its light value in light mode and its dark equivalent in dark mode.

extension Color {

    // MARK: Text
    /// Near-black / near-white
    static let kalPrimary  = Color(uiColor: .init(
        light: UIColor(hex: "#09090b"), dark: UIColor(hex: "#fafafa")))
    /// Medium zinc
    static let kalMuted    = Color(uiColor: .init(
        light: UIColor(hex: "#71717a"), dark: UIColor(hex: "#a1a1aa")))
    /// Light zinc
    static let kalTertiary = Color(uiColor: .init(
        light: UIColor(hex: "#a1a1aa"), dark: UIColor(hex: "#71717a")))

    // MARK: Surfaces
    /// Page / sheet background
    static let kalBackground = Color(uiColor: .init(
        light: UIColor(hex: "#ffffff"), dark: UIColor(hex: "#09090b")))
    /// Card / panel background
    static let kalSurface  = Color(uiColor: .init(
        light: UIColor(hex: "#ffffff"), dark: UIColor(hex: "#18181b")))
    /// Input / chip background
    static let kalInput    = Color(uiColor: .init(
        light: UIColor(hex: "#f4f4f5"), dark: UIColor(hex: "#27272a")))

    // MARK: Borders & Dividers
    /// Card border
    static let kalBorder   = Color(uiColor: .init(
        light: UIColor(hex: "#f0f0f0"), dark: UIColor(hex: "#27272a")))
    /// Row divider
    static let kalDivider  = Color(uiColor: .init(
        light: UIColor(hex: "#e4e4e7"), dark: UIColor(hex: "#3f3f46")))

    // MARK: Semantic — success
    static let kalDone     = Color(uiColor: .init(
        light: UIColor(hex: "#16a34a"), dark: UIColor(hex: "#22c55e")))
    static let kalDoneBg   = Color(uiColor: .init(
        light: UIColor(hex: "#dcfce7"), dark: UIColor(hex: "#052e16")))
    static let kalCardDone = Color(uiColor: .init(
        light: UIColor(hex: "#f7fdf9"), dark: UIColor(hex: "#0a1f12")))

    // MARK: Semantic — failure
    static let kalFail     = Color(uiColor: .init(
        light: UIColor(hex: "#dc2626"), dark: UIColor(hex: "#ef4444")))
    static let kalFailBg   = Color(uiColor: .init(
        light: UIColor(hex: "#fee2e2"), dark: UIColor(hex: "#450a0a")))
    static let kalCardFail = Color(uiColor: .init(
        light: UIColor(hex: "#fff8f8"), dark: UIColor(hex: "#1c0202")))

    // MARK: Semantic — accent
    static let kalToday    = Color(uiColor: .init(
        light: UIColor(hex: "#3b82f6"), dark: UIColor(hex: "#60a5fa")))
}

// MARK: - UIColor dynamic convenience

private extension UIColor {
    convenience init(light: UIColor, dark: UIColor) {
        self.init(dynamicProvider: { $0.userInterfaceStyle == .dark ? dark : light })
    }

    convenience init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var val: UInt64 = 0
        Scanner(string: h).scanHexInt64(&val)
        self.init(
            red:   CGFloat((val >> 16) & 0xff) / 255,
            green: CGFloat((val >>  8) & 0xff) / 255,
            blue:  CGFloat( val        & 0xff) / 255,
            alpha: 1
        )
    }
}
