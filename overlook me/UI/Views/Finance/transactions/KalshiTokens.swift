import SwiftUI

// MARK: - Kalshi Design Tokens
// Single source of truth for the Kalshi-inspired minimal, data-dense design.
// White backgrounds, no shadows, thin borders, zinc palette, compact typography.

// MARK: - Colour Tokens

extension Color {
    // Surface & Border
    static let kSurface       = Color.white
    static let kBorder         = Color(red: 0.941, green: 0.941, blue: 0.941)       // #f0f0f0
    static let kDividerBg      = Color(red: 0.957, green: 0.957, blue: 0.961)       // #f4f4f5
    static let kHoverSurface   = Color(red: 0.980, green: 0.980, blue: 0.980)       // #fafafa
    static let kInputBg        = Color(red: 0.945, green: 0.953, blue: 0.957)       // #f1f3f4
    static let kBorderMedium   = Color(red: 0.894, green: 0.894, blue: 0.906)       // #e4e4e7
    
    // Text
    static let kPrimary        = Color(red: 0.035, green: 0.035, blue: 0.043)       // #09090b
    static let kSecondary      = Color(red: 0.443, green: 0.443, blue: 0.478)       // #71717a
    static let kTertiary       = Color(red: 0.631, green: 0.631, blue: 0.667)       // #a1a1aa
    static let kPlaceholder    = Color(red: 0.831, green: 0.831, blue: 0.847)       // #d4d4d8
    
    // Semantic
    static let kGreen          = Color(red: 0.086, green: 0.639, blue: 0.290)       // #16a34a
    static let kGreenBg        = Color(red: 0.863, green: 0.988, blue: 0.906)       // #dcfce7
    static let kRed            = Color(red: 0.863, green: 0.149, blue: 0.149)       // #dc2626
    static let kRedBg          = Color(red: 0.996, green: 0.886, blue: 0.886)       // #fee2e2
    static let kRedLight       = Color(red: 0.973, green: 0.443, blue: 0.443)       // #f87171
    static let kBlue           = Color(red: 0.231, green: 0.510, blue: 0.965)       // #3b82f6
    static let kBlueBg         = Color(red: 0.231, green: 0.510, blue: 0.965).opacity(0.15)
    
    // Bar / track
    static let kTrack          = Color(red: 0.894, green: 0.894, blue: 0.906)       // #e4e4e7
}

// MARK: - KCard — Replaces GlassCard

/// Kalshi-style data card: white bg, thin border, 14px radius, no shadow.
struct KCard<Content: View>: View {
    var title: String? = nil
    var icon: String? = nil
    var eyebrow: String? = nil
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let eyebrow {
                KLabel(eyebrow)
            }
            
            if let title {
                HStack(spacing: 6) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.kSecondary)
                    }
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .tracking(-0.3)
                        .foregroundStyle(Color.kPrimary)
                }
            }
            
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.kSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.kBorder, lineWidth: 1)
        )
    }
}

// MARK: - KMetric — Large bold number with tiny label

/// Kalshi metric: 23px/700 number + 10px/500 uppercase label.
struct KMetric: View {
    let label: String
    let value: String
    var color: Color = Color.kPrimary
    
    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 23, weight: .bold))
                .tracking(-0.9)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            
            KLabel(label)
        }
    }
}

// MARK: - KLabel — 10px uppercase muted label

struct KLabel: View {
    let text: String
    var color: Color = Color.kTertiary
    
    init(_ text: String, color: Color = Color.kTertiary) {
        self.text = text
        self.color = color
    }
    
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .medium))
            .tracking(0.6)
            .foregroundStyle(color)
    }
}

// MARK: - KPill — Pill button

struct KPill: View {
    let label: String
    var icon: String? = nil
    var isActive: Bool = false
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                }
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(-0.1)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 6)
            .foregroundStyle(isActive ? Color.white : Color.kTertiary)
            .background(isActive ? Color.kPrimary : Color.kSurface, in: Capsule())
            .overlay(
                isActive ? nil : Capsule().stroke(Color.kBorderMedium, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - KDivider — Thin vertical metric divider

struct KDivider: View {
    var height: CGFloat = 26
    
    var body: some View {
        Rectangle()
            .fill(Color.kBorderMedium)
            .frame(width: 1, height: height)
    }
}

// MARK: - KStatusBadge

struct KStatusBadge: View {
    let text: String
    var style: BadgeStyle = .pending
    
    enum BadgeStyle {
        case pending, done, fail
        
        var bg: Color {
            switch self {
            case .pending: Color.kDividerBg
            case .done: Color.kGreenBg
            case .fail: Color.kRedBg
            }
        }
        
        var fg: Color {
            switch self {
            case .pending: Color.kSecondary
            case .done: Color.kGreen
            case .fail: Color.kRed
            }
        }
    }
    
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(0.6)
            .foregroundStyle(style.fg)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(style.bg, in: Capsule())
    }
}

// MARK: - KSectionHeader — Standardised section title with optional trailing

struct KSectionHeader: View {
    let title: String
    var trailing: String? = nil
    var trailingAction: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .tracking(-0.3)
                .foregroundStyle(Color.kPrimary)
            
            Spacer()
            
            if let trailing {
                Button {
                    trailingAction?()
                } label: {
                    Text(trailing.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(Color.kTertiary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - KStatRow — Horizontal metric strip with dividers (Habits-style)
// Numbers are always black. Color is ONLY for status badges, never on metric values.

struct KStatRow: View {
    let items: [(label: String, value: String, color: Color)]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                VStack(spacing: 3) {
                    Text(item.value)
                        .font(.system(size: 20, weight: .bold))
                        .tracking(-0.8)
                        .foregroundStyle(Color.kPrimary) // Always black — like Habits
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .contentTransition(.numericText())
                    
                    Text(item.label.uppercased())
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.54)
                        .foregroundStyle(Color.kTertiary)
                }
                .frame(maxWidth: .infinity)
                
                if index < items.count - 1 {
                    // Thin separator — exactly like Habits statSeparator
                    Rectangle()
                        .fill(Color.kBorderMedium)
                        .frame(width: 1, height: 26)
                }
            }
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.kSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.kBorder, lineWidth: 1)
                )
        )
    }
}

// MARK: - KEmptyState — Standardised empty placeholder

struct KEmptyState: View {
    let icon: String
    let title: String
    var message: String? = nil
    var ctaLabel: String? = nil
    var ctaAction: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(Color.kPlaceholder)
            
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .tracking(-0.3)
                .foregroundStyle(Color.kPrimary)
            
            if let message {
                Text(message)
                    .font(.system(size: 12, weight: .medium))
                    .tracking(-0.1)
                    .foregroundStyle(Color.kTertiary)
                    .multilineTextAlignment(.center)
            }
            
            if let ctaLabel {
                Button {
                    ctaAction?()
                } label: {
                    Text(ctaLabel.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(Color.kPrimary, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

// MARK: - KSearchField — Pill-shaped search input

struct KSearchField: View {
    let placeholder: String
    @Binding var text: String
    var onCommit: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.kTertiary)
            
            TextField(placeholder, text: $text)
                .font(.system(size: 13, weight: .medium))
                .tracking(-0.1)
                .foregroundStyle(Color.kPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit { onCommit?() }
            
            if !text.isEmpty {
                Button {
                    text = ""
                    onCommit?()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.kTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.kInputBg, in: Capsule())
    }
}

// MARK: - KProgressBar — Tiny capsule progress indicator

struct KProgressBar: View {
    let ratio: Double
    var color: Color = Color.kPrimary
    var trackColor: Color = Color.kTrack
    var height: CGFloat = 5
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(trackColor)
                Capsule().fill(color)
                    .frame(width: max(2, geo.size.width * min(max(ratio, 0), 1)))
            }
        }
        .frame(height: height)
    }
}

// MARK: - KAccentCard — Card with left color accent line

struct KAccentCard<Content: View>: View {
    var accent: Color = Color.kPrimary
    @ViewBuilder let content: Content
    
    var body: some View {
        HStack(spacing: 0) {
            Capsule()
                .fill(accent)
                .frame(width: 3)
                .padding(.vertical, 4)
            
            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 12)
        }
        .padding(14)
        .background(Color.kSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.kBorder, lineWidth: 1))
    }
}

// MARK: - KPressButtonStyle — Subtle scale-down press animation

struct KPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

