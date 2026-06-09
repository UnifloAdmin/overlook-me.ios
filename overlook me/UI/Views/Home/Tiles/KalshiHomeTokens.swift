import SwiftUI

// MARK: - Kalshi Design Tokens
// Single source of truth — mirrors docs/ui-kalshi.md exactly.
// Never invent new values. Use what is specified here.

enum Kalshi {

    // MARK: - Adaptive helper

    /// Shorthand for a color that adapts to light / dark mode.
    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }

    // MARK: Surface & Border

    static let bg          = adaptive(light: .white,
                                       dark:  UIColor(red: 0.035, green: 0.035, blue: 0.043, alpha: 1))   // #09090b
    static let cardBorder  = adaptive(light: UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.12),        // subtle black
                                       dark:  UIColor(red: 0.153, green: 0.153, blue: 0.165, alpha: 1))   // #27272a
    static let dividerBg   = adaptive(light: UIColor(red: 0.957, green: 0.957, blue: 0.961, alpha: 1),    // #f4f4f5
                                       dark:  UIColor(red: 0.094, green: 0.094, blue: 0.106, alpha: 1))   // #18181b
    static let hoverBg     = adaptive(light: UIColor(red: 0.980, green: 0.980, blue: 0.980, alpha: 1),    // #fafafa
                                       dark:  UIColor(red: 0.094, green: 0.094, blue: 0.106, alpha: 1))   // #18181b
    static let inputBg     = adaptive(light: UIColor(red: 0.945, green: 0.953, blue: 0.957, alpha: 1),    // #f1f3f4
                                       dark:  UIColor(red: 0.094, green: 0.094, blue: 0.106, alpha: 1))   // #18181b
    static let inputBorder = adaptive(light: UIColor(red: 0.894, green: 0.894, blue: 0.906, alpha: 1),    // #e4e4e7
                                       dark:  UIColor(red: 0.220, green: 0.220, blue: 0.243, alpha: 1))   // #3f3f46

    // MARK: Text

    static let textPrimary     = adaptive(light: UIColor(red: 0.035, green: 0.035, blue: 0.043, alpha: 1),  // #09090b
                                           dark:  UIColor(red: 0.980, green: 0.980, blue: 0.984, alpha: 1)) // #fafafc
    static let textSecondary   = adaptive(light: UIColor(red: 0.443, green: 0.443, blue: 0.478, alpha: 1),  // #71717a
                                           dark:  UIColor(red: 0.631, green: 0.631, blue: 0.667, alpha: 1)) // #a1a1aa
    static let textMuted       = adaptive(light: UIColor(red: 0.631, green: 0.631, blue: 0.667, alpha: 1),  // #a1a1aa
                                           dark:  UIColor(red: 0.443, green: 0.443, blue: 0.478, alpha: 1)) // #71717a
    static let textPlaceholder = adaptive(light: UIColor(red: 0.831, green: 0.831, blue: 0.847, alpha: 1),  // #d4d4d8
                                           dark:  UIColor(red: 0.278, green: 0.278, blue: 0.298, alpha: 1)) // #47474c

    // MARK: Semantic — Status Colours

    static let green   = Color(red: 0.086, green: 0.639, blue: 0.290)           // #16a34a
    static let greenDk = Color(red: 0.082, green: 0.502, blue: 0.239)           // #15803d
    static let red     = Color(red: 0.863, green: 0.149, blue: 0.149)           // #dc2626
    static let blue    = Color(red: 0.231, green: 0.510, blue: 0.965)           // #3b82f6
    static let orange  = Color(red: 0.973, green: 0.529, blue: 0.443)           // #f87171 (missed/warning)
    static let amber   = Color(red: 0.984, green: 0.749, blue: 0.141)           // #fbbf24

    // Semantic backgrounds
    static let greenBg = adaptive(light: UIColor(red: 0.863, green: 0.988, blue: 0.906, alpha: 1),         // #dcfce7
                                   dark:  UIColor(red: 0.051, green: 0.176, blue: 0.098, alpha: 1))         // #0d2d19
    static let redBg   = adaptive(light: UIColor(red: 0.996, green: 0.886, blue: 0.886, alpha: 1),         // #fee2e2
                                   dark:  UIColor(red: 0.196, green: 0.059, blue: 0.059, alpha: 1))         // #320f0f

    // Week segment bar colours
    static let segDone     = green                                                // #16a34a
    static let segMissed   = Color(red: 0.988, green: 0.647, blue: 0.647)       // #fca5a5
    static let segSkipped  = amber                                                // #fbbf24
    static let segToday    = Color(red: 0.576, green: 0.773, blue: 0.988)       // #93c5fd
    static let segFuture   = dividerBg.opacity(0.5)                              // #f4f4f5 @ 50%

    // Progress bar unfilled
    static let barUnfilled = Color(red: 0.894, green: 0.894, blue: 0.906)       // #e4e4e7

    // MARK: Sizing

    static let cardRadius: CGFloat    = 14
    static let pillRadius: CGFloat    = 999
    static let segRadius: CGFloat     = 2
    static let progressRadius: CGFloat = 999
    static let iconBtnSize: CGFloat   = 28
    static let progressBarH: CGFloat  = 7

    // MARK: Spacing

    static let cardPadH: CGFloat = 14
    static let cardPadTop: CGFloat = 14
    static let cardPadBot: CGFloat = 12
    static let cardGap: CGFloat = 10
    static let footerGap: CGFloat = 6

    // MARK: Animation

    static let micro: Animation   = .easeInOut(duration: 0.12)
    static let normal: Animation  = .easeInOut(duration: 0.15)
    static let cardEnter: Animation = .easeOut(duration: 0.35)
}

// MARK: - Card Modifier

/// White card with 1px border, 14px radius — the Kalshi card container.
struct KalshiCardModifier: ViewModifier {
    var paddingH: CGFloat = Kalshi.cardPadH
    var paddingTop: CGFloat = Kalshi.cardPadTop
    var paddingBot: CGFloat = Kalshi.cardPadBot

    func body(content: Content) -> some View {
        content
            .background(Kalshi.bg)
            .clipShape(RoundedRectangle(cornerRadius: Kalshi.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Kalshi.cardRadius, style: .continuous)
                    .stroke(Kalshi.cardBorder, lineWidth: 1)
            )
    }
}

extension View {
    /// Apply the Kalshi card container style (white bg, 1px border, 14px radius).
    func kalshiCard() -> some View {
        modifier(KalshiCardModifier())
    }
}

// MARK: - Pill Button Style

struct KalshiPillButtonStyle: ButtonStyle {
    var isPrimary: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .tracking(-0.12)
            .padding(.horizontal, 13)
            .padding(.vertical, 6)
            .background(isPrimary ? Kalshi.textPrimary : Kalshi.bg)
            .foregroundStyle(isPrimary ? Color.white : Kalshi.textMuted)
            .clipShape(Capsule())
            .overlay(
                isPrimary
                    ? nil
                    : Capsule().stroke(Kalshi.inputBorder, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(Kalshi.micro, value: configuration.isPressed)
    }
}

// MARK: - Status Badge

struct KalshiStatusBadge: View {
    enum Variant { case pending, done, fail }
    let text: String
    let variant: Variant

    private var bgColor: Color {
        switch variant {
        case .pending: return Kalshi.dividerBg
        case .done:    return Kalshi.greenBg
        case .fail:    return Kalshi.redBg
        }
    }

    private var fgColor: Color {
        switch variant {
        case .pending: return Kalshi.textSecondary
        case .done:    return Kalshi.greenDk
        case .fail:    return Kalshi.red
        }
    }

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .tracking(0.6)
            .textCase(.uppercase)
            .foregroundStyle(fgColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(bgColor, in: Capsule())
    }
}

// MARK: - Kalshi Divider (1px #f0f0f0)

struct KalshiDivider: View {
    var body: some View {
        Rectangle()
            .fill(Kalshi.cardBorder)
            .frame(height: 1)
    }
}

// MARK: - Typography helpers

extension View {
    /// Large metric number: 23px / 700 / -.04em
    func kalshiMetric() -> some View {
        self
            .font(.system(size: 23, weight: .bold))
            .tracking(-0.92)
            .foregroundStyle(Kalshi.textPrimary)
    }

    /// Card title: 14px / 600 / -.02em
    func kalshiCardTitle() -> some View {
        self
            .font(.system(size: 14, weight: .semibold))
            .tracking(-0.28)
            .foregroundStyle(Kalshi.textPrimary)
    }

    /// Eyebrow / Section label: 10px / 600 / uppercase / .06em
    func kalshiEyebrow() -> some View {
        self
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.6)
            .textCase(.uppercase)
            .foregroundStyle(Kalshi.textMuted)
    }

    /// Metric label: 10px / 500 / uppercase / .06em
    func kalshiMetricLabel() -> some View {
        self
            .font(.system(size: 10, weight: .medium))
            .tracking(0.6)
            .textCase(.uppercase)
            .foregroundStyle(Kalshi.textMuted)
    }

    /// Body / stat value: 13px / 600 / -.01em
    func kalshiBody() -> some View {
        self
            .font(.system(size: 13, weight: .semibold))
            .tracking(-0.13)
            .foregroundStyle(Kalshi.textPrimary)
    }

    /// Secondary body: 12px / 500 / #71717a
    func kalshiSecondary() -> some View {
        self
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Kalshi.textSecondary)
    }
}
