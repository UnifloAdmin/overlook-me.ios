//
//  LandingView.swift
//  overlook me
//
//  Created by Naresh Chandra on 1/8/26.
//

import SwiftUI

// MARK: - Screen

private enum AuthScreen: Equatable {
    case landing, login, signup, forgot, twofactor
}

private enum FormField: Hashable {
    case firstName, lastName, email, password, confirmPassword
}

// MARK: - Wave Shape

private struct WaveShape: Shape {
    var heightRatio: CGFloat

    var animatableData: CGFloat {
        get { heightRatio }
        set { heightRatio = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let h = rect.height * heightRatio
        var p = Path()
        p.move(to: .zero)
        p.addLine(to: CGPoint(x: rect.maxX, y: 0))
        p.addLine(to: CGPoint(x: rect.maxX, y: h * 0.72))
        p.addCurve(
            to: CGPoint(x: 0, y: h),
            control1: CGPoint(x: rect.maxX * 0.55, y: h * 1.12),
            control2: CGPoint(x: rect.maxX * 0.30, y: h * 0.68)
        )
        p.closeSubpath()
        return p
    }
}

// MARK: - Wave Decorations

private struct WaveDecorations: View {
    var isLanding: Bool
    var isDark: Bool

    private struct Decoration: Identifiable {
        let id: Int
        let symbol: String
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let opacity: Double
        let rotation: Double
        let floatSpeed: Double   // animation duration (0 = no float)
        let floatRange: CGFloat  // how far it bobs
    }

    // Laid out on a staggered 5-column grid, no overlaps
    private var items: [Decoration] {[
        // ── Row 1  y ≈ 0.08 ──
        Decoration(id: 0,  symbol: "sparkle",                x: 0.10, y: 0.07, size: 18, opacity: 0.20, rotation: 30,  floatSpeed: 2.0, floatRange: 3),
        Decoration(id: 1,  symbol: "dollarsign.circle.fill", x: 0.32, y: 0.09, size: 40, opacity: 0.20, rotation: 0,   floatSpeed: 3.4, floatRange: 6),
        Decoration(id: 2,  symbol: "creditcard.fill",        x: 0.56, y: 0.08, size: 34, opacity: 0.18, rotation: -8,  floatSpeed: 4.0, floatRange: 5),
        Decoration(id: 3,  symbol: "waveform.path.ecg",      x: 0.80, y: 0.09, size: 38, opacity: 0.18, rotation: 0,   floatSpeed: 3.8, floatRange: 5),

        // ── Row 2  y ≈ 0.22 (offset columns) ──
        Decoration(id: 4,  symbol: "leaf.fill",              x: 0.12, y: 0.22, size: 36, opacity: 0.20, rotation: 25,  floatSpeed: 2.8, floatRange: 7),
        Decoration(id: 5,  symbol: "heart.fill",             x: 0.36, y: 0.23, size: 44, opacity: 0.22, rotation: -10, floatSpeed: 3.0, floatRange: 7),
        Decoration(id: 6,  symbol: "banknote.fill",          x: 0.60, y: 0.22, size: 30, opacity: 0.16, rotation: 8,   floatSpeed: 4.2, floatRange: 5),
        Decoration(id: 7,  symbol: "target",                 x: 0.84, y: 0.23, size: 28, opacity: 0.15, rotation: 0,   floatSpeed: 4.4, floatRange: 4),

        // ── Row 3  y ≈ 0.36 ──
        Decoration(id: 8,  symbol: "moon.stars.fill",        x: 0.10, y: 0.37, size: 32, opacity: 0.18, rotation: 15,  floatSpeed: 3.2, floatRange: 6),
        Decoration(id: 9,  symbol: "chart.line.uptrend.xyaxis", x: 0.34, y: 0.36, size: 30, opacity: 0.16, rotation: 0, floatSpeed: 3.0, floatRange: 5),
        Decoration(id: 10, symbol: "drop.fill",              x: 0.56, y: 0.37, size: 28, opacity: 0.17, rotation: 12,  floatSpeed: 3.6, floatRange: 6),
        Decoration(id: 11, symbol: "figure.run",             x: 0.78, y: 0.36, size: 36, opacity: 0.17, rotation: 0,   floatSpeed: 3.8, floatRange: 5),
        Decoration(id: 12, symbol: "sparkle",                x: 0.95, y: 0.37, size: 14, opacity: 0.18, rotation: 45,  floatSpeed: 2.2, floatRange: 3),

        // ── Row 4  y ≈ 0.50 (offset columns) ──
        Decoration(id: 13, symbol: "figure.yoga",            x: 0.10, y: 0.51, size: 30, opacity: 0.15, rotation: 0,   floatSpeed: 4.0, floatRange: 5),
        Decoration(id: 14, symbol: "flame.fill",             x: 0.34, y: 0.50, size: 30, opacity: 0.17, rotation: -6,  floatSpeed: 2.8, floatRange: 6),
        Decoration(id: 15, symbol: "brain.head.profile",     x: 0.56, y: 0.51, size: 28, opacity: 0.15, rotation: -5,  floatSpeed: 3.5, floatRange: 5),
        Decoration(id: 16, symbol: "wallet.bifold.fill",     x: 0.78, y: 0.50, size: 26, opacity: 0.14, rotation: -8,  floatSpeed: 4.0, floatRange: 4),

        // ── Row 5  y ≈ 0.64 ──
        Decoration(id: 17, symbol: "checkmark.circle.fill",  x: 0.10, y: 0.65, size: 26, opacity: 0.16, rotation: 0,   floatSpeed: 3.6, floatRange: 5),
        Decoration(id: 18, symbol: "clock.fill",             x: 0.32, y: 0.64, size: 26, opacity: 0.15, rotation: 0,   floatSpeed: 3.4, floatRange: 5),
        Decoration(id: 19, symbol: "stethoscope",            x: 0.54, y: 0.65, size: 26, opacity: 0.14, rotation: 10,  floatSpeed: 4.2, floatRange: 4),
        Decoration(id: 20, symbol: "bell.fill",              x: 0.76, y: 0.64, size: 22, opacity: 0.13, rotation: 8,   floatSpeed: 3.0, floatRange: 5),

        // ── Row 6  y ≈ 0.78 (fewer — wave curves away) ──
        Decoration(id: 21, symbol: "sparkle",                x: 0.06, y: 0.78, size: 16, opacity: 0.16, rotation: 20,  floatSpeed: 2.4, floatRange: 4),
        Decoration(id: 22, symbol: "zzz",                    x: 0.24, y: 0.78, size: 22, opacity: 0.14, rotation: 10,  floatSpeed: 2.8, floatRange: 6),
        Decoration(id: 23, symbol: "bed.double.fill",        x: 0.44, y: 0.77, size: 24, opacity: 0.13, rotation: 0,   floatSpeed: 4.6, floatRange: 4),
        Decoration(id: 24, symbol: "calendar",               x: 0.64, y: 0.76, size: 22, opacity: 0.12, rotation: -5,  floatSpeed: 4.8, floatRange: 3),

        // ── Tiny dots scattered in gaps ──
        Decoration(id: 25, symbol: "circle.fill",            x: 0.22, y: 0.15, size: 6,  opacity: 0.14, rotation: 0, floatSpeed: 0, floatRange: 0),
        Decoration(id: 26, symbol: "circle.fill",            x: 0.70, y: 0.15, size: 5,  opacity: 0.12, rotation: 0, floatSpeed: 0, floatRange: 0),
        Decoration(id: 27, symbol: "circle.fill",            x: 0.46, y: 0.30, size: 6,  opacity: 0.12, rotation: 0, floatSpeed: 0, floatRange: 0),
        Decoration(id: 28, symbol: "circle.fill",            x: 0.22, y: 0.44, size: 5,  opacity: 0.10, rotation: 0, floatSpeed: 0, floatRange: 0),
        Decoration(id: 29, symbol: "circle.fill",            x: 0.68, y: 0.44, size: 7,  opacity: 0.12, rotation: 0, floatSpeed: 0, floatRange: 0),
        Decoration(id: 30, symbol: "circle.fill",            x: 0.46, y: 0.58, size: 5,  opacity: 0.10, rotation: 0, floatSpeed: 0, floatRange: 0),
        Decoration(id: 31, symbol: "circle.fill",            x: 0.92, y: 0.56, size: 6,  opacity: 0.10, rotation: 0, floatSpeed: 0, floatRange: 0),
    ]}

    var body: some View {
        let boost: Double = isDark ? 1.4 : 1.0
        GeometryReader { geo in
            ForEach(items) { item in
                FloatingIcon(
                    symbol: item.symbol,
                    baseSize: isLanding ? item.size : item.size * 0.45,
                    opacity: item.opacity * boost,
                    rotation: item.rotation,
                    floatSpeed: item.floatSpeed,
                    floatRange: isLanding ? item.floatRange : item.floatRange * 0.4
                )
                .position(x: geo.size.width * item.x, y: geo.size.height * item.y)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Floating Icon

private struct FloatingIcon: View {
    let symbol: String
    let baseSize: CGFloat
    let opacity: Double
    let rotation: Double
    let floatSpeed: Double
    let floatRange: CGFloat

    @State private var floating = false

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: baseSize))
            .foregroundStyle(.white.opacity(opacity))
            .rotationEffect(.degrees(rotation))
    }
}

// MARK: - Slide-to-Login Button

private struct SlideToLoginButton: View {
    var isDark: Bool
    var onSlideComplete: () -> Void

    private let trackHeight: CGFloat = 64
    private let thumbSize: CGFloat = 54
    private let thumbPadding: CGFloat = 5

    @State private var dragOffset: CGFloat = 0
    @State private var completed = false
    @State private var shimmerPhase: CGFloat = -0.3
    @State private var arrowPulse = false
    @State private var showCheck = false

    private var thumbColor: Color { Color.kalPrimary }
    private var trackColor: Color {
        isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)
    }
    private var trackBorder: Color {
        isDark ? Color.white.opacity(0.10) : Color.black.opacity(0.08)
    }

    var body: some View {
        GeometryReader { geo in
            let maxDrag = geo.size.width - thumbSize - thumbPadding * 2

            // Drag progress 0…1
            let progress = maxDrag > 0 ? dragOffset / maxDrag : 0

            ZStack {
                // ── Track (pill shape) ──
                Capsule(style: .continuous)
                    .fill(trackColor)
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(trackBorder, lineWidth: 1)
                    )

                // ── Animated hint chevrons (>>>) ──
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(isDark ? .white.opacity(0.18) : .black.opacity(0.14))
                            .offset(x: arrowPulse ? 4 : -2)
                            .opacity(arrowPulse ? 0.6 : 0.2)
                            .animation(
                                .easeInOut(duration: 1.0)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.15),
                                value: arrowPulse
                            )
                    }
                }
                .offset(x: 30)
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(completed ? 0 : max(0, 1.0 - progress * 3.0))

                // ── iOS call-screen glimmer label ──
                Text("Slide to continue")
                    .font(Font.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(isDark ? .white.opacity(0.25) : .black.opacity(0.20))
                    .overlay(
                        // Bright glimmer sweep
                        Text("Slide to continue")
                            .font(Font.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(isDark ? .white.opacity(0.85) : .black.opacity(0.70))
                            .mask(
                                LinearGradient(
                                    stops: [
                                        .init(color: .clear, location: shimmerPhase - 0.12),
                                        .init(color: .white, location: shimmerPhase - 0.02),
                                        .init(color: .white, location: shimmerPhase + 0.02),
                                        .init(color: .clear, location: shimmerPhase + 0.12),
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    // Fade out as user drags
                    .opacity(completed ? 0 : max(0, 1.0 - progress * 2.5))
                    .offset(x: completed ? 40 : progress * 20.0)
                    .animation(.easeOut(duration: 0.2), value: progress)

                // ── Filled track behind thumb (pill) ──
                Capsule(style: .continuous)
                    .fill(thumbColor.opacity(isDark ? 0.08 : 0.05))
                    .frame(width: dragOffset + thumbSize + thumbPadding * 2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // ── Thumb (pill) ──
                ZStack {
                    // Arrow icon
                    Image(systemName: "arrow.right")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(isDark ? .black : .white)
                        .opacity(showCheck ? 0 : 1)
                        .scaleEffect(showCheck ? 0.3 : 1)

                    // Checkmark on complete
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(isDark ? .black : .white)
                        .opacity(showCheck ? 1 : 0)
                        .scaleEffect(showCheck ? 1 : 0.3)
                }
                .frame(width: thumbSize, height: thumbSize)
                .background(
                    Capsule(style: .continuous)
                        .fill(thumbColor)
                        .shadow(color: thumbColor.opacity(isDark ? 0.0 : 0.20), radius: 8, y: 3)
                        .shadow(color: .black.opacity(isDark ? 0.30 : 0.10), radius: 2, y: 1)
                )
                .offset(x: -(geo.size.width / 2 - thumbSize / 2 - thumbPadding) + dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            guard !completed else { return }
                            let newOffset = min(max(0, value.translation.width), maxDrag)
                            dragOffset = newOffset
                            // Light haptic ticks at 25%, 50%, 75%
                            let pct = newOffset / maxDrag
                            for threshold in [0.25, 0.5, 0.75] {
                                let prev = max(0, (newOffset - abs(value.velocity.width) * 0.016)) / maxDrag
                                if prev < threshold && pct >= threshold {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                            }
                        }
                        .onEnded { _ in
                            guard !completed else { return }
                            if dragOffset > maxDrag * 0.65 {
                                // ── Complete ──
                                withAnimation(.spring(duration: 0.35, bounce: 0.12)) {
                                    dragOffset = maxDrag
                                    completed = true
                                }
                                withAnimation(.spring(duration: 0.3).delay(0.15)) {
                                    showCheck = true
                                }
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                                    onSlideComplete()
                                }
                            } else {
                                // ── Snap back ──
                                withAnimation(.spring(duration: 0.5, bounce: 0.25)) {
                                    dragOffset = 0
                                }
                                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            }
                        }
                )
            }
        }
        .frame(height: trackHeight)
        .onAppear {
            withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                shimmerPhase = 1.3
            }
            // Stagger arrow pulse start
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                arrowPulse = true
            }
        }
    }
}

// MARK: - Landing View

struct LandingView: View {
    @Environment(\.injected) private var container: DIContainer
    @Environment(\.colorScheme) private var colorScheme

    private var interactor: AuthInteractor { container.interactors.authInteractor }

    @State private var screen: AuthScreen = .landing
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var twoFactorCode = ""
    @State private var twoFactorUserId = ""
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @State private var rememberMe = false
    @State private var errorMessage = ""
    @State private var successMessage = ""
    @State private var isLoading = false
    @State private var landingAppeared = false
    @State private var screenHeight: CGFloat = 852
    @State private var showQuickUnlockPrompt = false
    @FocusState private var focusedField: FormField?
    @FocusState private var otpFocused: Bool
    @AppStorage("isFaceIdDisabled") private var isFaceIdDisabled = false
    @AppStorage("hasAskedQuickUnlock") private var hasAskedQuickUnlock = false

    private var accent: Color { Color.wellnessGreen }
    private var isDark: Bool { colorScheme == .dark }
    private var buttonGold: Color { Color(red: 0.95, green: 0.72, blue: 0.22) }

    private var waveColor: Color {
        isDark ? Color(red: 0.12, green: 0.12, blue: 0.14) : Color(red: 0.04, green: 0.04, blue: 0.04)
    }

    private var pageBg: Color {
        Color.kalBackground
    }

    private var cardBg: Color {
        isDark ? Color.white.opacity(0.06) : .white
    }

    private var glassTint: Color {
        isDark ? Color.white.opacity(0.12) : Color.white.opacity(0.45)
    }

    private var separatorColor: Color {
        isDark ? Color.white.opacity(0.12) : Color.secondary.opacity(0.2)
    }

    private var fieldIconColor: Color {
        isDark ? Color.white.opacity(0.5) : Color.secondary
    }

    private var glassCardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(glassTint)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(isDark ? 0.30 : 0.55), lineWidth: 1)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.black.opacity(isDark ? 0.20 : 0.06), lineWidth: 1)
                    .blur(radius: 1)
                    .offset(y: 1)
                    .mask(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.black, .clear],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                    )
            }
            .shadow(color: .black.opacity(isDark ? 0.20 : 0.07), radius: 14, y: 8)
            .shadow(color: accent.opacity(isDark ? 0.16 : 0.05), radius: 10, y: 2)
    }

    private var waveRatio: CGFloat {
        switch screen {
        case .landing:   0.68
        case .login:     0.32
        case .signup:    0.24
        case .forgot:    0.32
        case .twofactor: 0.32
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            GeometryReader { geo in Color.clear.onAppear { screenHeight = geo.size.height } }
                .ignoresSafeArea()
            pageBg.ignoresSafeArea()

            // Wave header
            WaveShape(heightRatio: waveRatio)
                .fill(waveColor)
                .overlay {
                    WaveDecorations(isLanding: screen == .landing, isDark: isDark)
                        .clipShape(WaveShape(heightRatio: waveRatio))
                        .animation(.spring(duration: 0.6, bounce: 0.15), value: screen)
                }
                .ignoresSafeArea(edges: .top)
                .animation(.spring(duration: 0.6, bounce: 0.15), value: waveRatio)

            // Content
            Group {
                switch screen {
                case .landing:   landingContent
                default:         formContent
                }
            }

            // Top nav pills (landing only)
            if screen == .landing {
                VStack(alignment: .trailing, spacing: 6) {
                    // Row 1: Integrations
                    HStack(spacing: 8) {
                        Spacer()
                        landingNavPill("HealthKit", icon: "heart.fill", tint: nil)
                        landingNavPill("Plaid", icon: "building.columns.fill", tint: nil)
                    }
                    // Row 2: Info
                    HStack(spacing: 8) {
                        Spacer()
                        landingNavPill("Features", icon: "square.grid.2x2.fill", tint: nil)
                        landingNavPill("Pricing", icon: "tag.fill", tint: nil)
                        landingNavPill("Early Access", icon: "sparkles", tint: nil)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .opacity(landingAppeared ? 1 : 0)
                .offset(y: landingAppeared ? 0 : -10)
            }
        }
        .confirmationDialog("Use Face ID for quick login?", isPresented: $showQuickUnlockPrompt, titleVisibility: .visible) {
            Button("Enable Face ID") {
                isFaceIdDisabled = false
                hasAskedQuickUnlock = true
            }
            Button("Not now", role: .cancel) {
                hasAskedQuickUnlock = true
            }
        } message: {
            Text("Next time you can unlock and continue faster with Face ID.")
        }
    }

    // MARK: - Landing Nav Pill

    private func landingNavPill(_ title: String, icon: String, tint: Color?) -> some View {
        Button {
            // TODO: Navigate to the appropriate screen
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.90))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.15))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
            )
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Landing Screen
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var landingContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            // ── Hero section ──
            VStack(alignment: .leading, spacing: 20) {
                // App name
                VStack(alignment: .leading, spacing: 4) {
                    Text("Overlook Me")
                        .font(.system(size: 38, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.kalPrimary)
                    Text("Your life, one dashboard.")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.kalMuted)
                }
                .opacity(landingAppeared ? 1 : 0)
                .offset(y: landingAppeared ? 0 : 24)

                // Integration badges
                HStack(spacing: 8) {
                    integrationBadge("HealthKit", icon: "heart.fill", color: .pink)
                    integrationBadge("Plaid", icon: "building.columns.fill", color: Color.kalDone)
                    integrationBadge("AI Insights", icon: "brain.head.profile", color: Color.kalToday)
                }
                .opacity(landingAppeared ? 1 : 0)
                .offset(y: landingAppeared ? 0 : 18)

                // Tagline
                Text("Track wellness · Manage finances · Build habits")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.kalTertiary)
                    .opacity(landingAppeared ? 1 : 0)
                    .offset(y: landingAppeared ? 0 : 14)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 36)

            // ── Slide button ──
            SlideToLoginButton(isDark: isDark) {
                _Concurrency.Task { await attemptPasskeyThenLogin() }
            }
            .opacity(landingAppeared ? 1 : 0)
            .offset(y: landingAppeared ? 0 : 12)
            .padding(.horizontal, 28)
            .padding(.bottom, 44)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.75, bounce: 0.12).delay(0.25)) {
                landingAppeared = true
            }
        }
        .onDisappear { landingAppeared = false }
        .transition(.opacity)
    }

    // MARK: - Integration Badge

    private func integrationBadge(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.kalPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(Color.kalInput)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.kalBorder, lineWidth: 0.5)
        )
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Form Screen
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var formContent: some View {
        VStack(spacing: 0) {
            // Back button (over the wave)
            HStack {
                Button {
                    let target: AuthScreen = (screen == .forgot || screen == .twofactor) ? .login : .landing
                    navigateTo(target)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Spacer to push content below the wave
                    Color.clear.frame(height: waveSpacerHeight)

                    // Title
                    Text(formTitle)
                        .font(.system(size: 26, weight: .bold))
                        .padding(.horizontal, 28)
                        .padding(.bottom, 20)

                    // Alerts
                    alertBanners
                        .padding(.horizontal, 28)

                    // Form card
                    VStack(alignment: .leading, spacing: 16) {
                        formFields

                        if screen == .login {
                            loginExtras
                        }

                        submitButton
                            .padding(.top, 6)

                        if screen == .login {
                            passkeyDivider
                            passkeyLoginButton
                        }
                    }
                    .padding(18)
                    .background(glassCardBackground)
                    .padding(.horizontal, 22)

                    // Switch link
                    formLink
                        .padding(.top, 18)
                        .padding(.bottom, 28)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .offset(x: 30)),
            removal: .opacity.combined(with: .offset(x: -30))
        ))
    }

    private var waveSpacerHeight: CGFloat {
        switch screen {
        case .landing:   0
        case .login:     screenHeight * 0.20
        case .signup:    screenHeight * 0.12
        case .forgot:    screenHeight * 0.20
        case .twofactor: screenHeight * 0.20
        }
    }

    // MARK: - Title

    private var formTitle: String {
        switch screen {
        case .landing:   ""
        case .login:     "Sign in"
        case .signup:    "Sign up"
        case .forgot:    "Reset password"
        case .twofactor: "Verification"
        }
    }

    // MARK: - Form Fields

    @ViewBuilder
    private var formFields: some View {
        switch screen {
        case .landing:
            EmptyView()

        case .login:
            underlineField("Email", text: $email, icon: "envelope", focus: .email, keyboard: .emailAddress, content: .emailAddress, submitLabel: .next) {
                focusedField = .password
            }
            underlineSecureField("Password", text: $password, isVisible: $showPassword, icon: "lock", focus: .password, content: .password, submitLabel: .go) {
                _Concurrency.Task { await performSubmit() }
            }

        case .signup:
            underlineField("First Name", text: $firstName, icon: "person", focus: .firstName, capitalize: true, content: .givenName, submitLabel: .next) {
                focusedField = .lastName
            }
            underlineField("Last Name", text: $lastName, icon: "person", focus: .lastName, capitalize: true, content: .familyName, submitLabel: .next) {
                focusedField = .email
            }
            underlineField("Email", text: $email, icon: "envelope", focus: .email, keyboard: .emailAddress, content: .emailAddress, submitLabel: .next) {
                focusedField = .password
            }
            underlineSecureField("Password", text: $password, isVisible: $showPassword, icon: "lock", focus: .password, content: .newPassword, submitLabel: .next) {
                focusedField = .confirmPassword
            }
            underlineSecureField("Confirm Password", text: $confirmPassword, isVisible: $showConfirmPassword, icon: "lock.rotation", focus: .confirmPassword, content: .newPassword, submitLabel: .go) {
                _Concurrency.Task { await performSubmit() }
            }

        case .forgot:
            underlineField("Email", text: $email, icon: "envelope", focus: .email, keyboard: .emailAddress, content: .emailAddress, submitLabel: .go) {
                _Concurrency.Task { await performSubmit() }
            }

        case .twofactor:
            otpBoxes
        }
    }

    // MARK: - Login Extras

    private var loginExtras: some View {
        HStack {
            Button {
                rememberMe.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: rememberMe ? "checkmark.square.fill" : "square")
                        .foregroundStyle(rememberMe ? accent : .secondary)
                        .font(.body)
                    Text("Remember Me")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.primary)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button("Forgot Password?") { navigateTo(.forgot) }
                .font(.footnote.weight(.medium))
                .foregroundStyle(accent)
        }
    }

    // MARK: - Alert Banners

    @ViewBuilder
    private var alertBanners: some View {
        if !errorMessage.isEmpty {
            alertRow(errorMessage, isError: true)
                .padding(.bottom, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
        if !successMessage.isEmpty {
            alertRow(successMessage, isError: false)
                .padding(.bottom, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func alertRow(_ message: String, isError: Bool) -> some View {
        let tint: Color = isError ? .red : accent

        return HStack(spacing: 10) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(tint)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                withAnimation(.spring(duration: 0.3)) {
                    if isError { errorMessage = "" } else { successMessage = "" }
                }
            } label: {
                Image(systemName: "xmark").font(.caption2.bold()).foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(isDark ? 0.15 : 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(tint.opacity(isDark ? 0.25 : 0.12), lineWidth: 1)
                )
        )
    }

    // MARK: - OTP Boxes

    private var otpBoxes: some View {
        VStack(spacing: 14) {
            ZStack {
                HStack(spacing: 10) {
                    ForEach(0..<6, id: \.self) { index in
                        otpDigit(at: index)
                    }
                }

                TextField("", text: $twoFactorCode)
                    .keyboardType(.numberPad)
                    .focused($otpFocused)
                    .foregroundStyle(.clear)
                    .tint(.clear)
                    .accentColor(.clear)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onChange(of: twoFactorCode) { _, newValue in
                        let cleaned = String(newValue.prefix(6).filter(\.isNumber))
                        if cleaned != newValue { twoFactorCode = cleaned }
                        if cleaned.count == 6 {
                            _Concurrency.Task { await submitTwoFactor() }
                        }
                    }
            }
            .onTapGesture { otpFocused = true }

            Text("Enter the code from your authenticator app")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private func otpDigit(at index: Int) -> some View {
        let chars = Array(twoFactorCode)
        let digit = index < chars.count ? String(chars[index]) : ""
        let active = index == twoFactorCode.count && otpFocused
        let filled = index < chars.count

        return Text(digit)
            .font(.system(.title2, design: .monospaced, weight: .bold))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(filled ? accent.opacity(isDark ? 0.15 : 0.06) : cardBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(active ? accent : separatorColor, lineWidth: active ? 2 : 1)
            )
            .scaleEffect(active ? 1.05 : 1.0)
            .animation(.spring(duration: 0.25), value: active)
    }

    // MARK: - Submit Button

    private var submitButton: some View {
        Button {
            focusedField = nil
            otpFocused = false
            _Concurrency.Task { await performSubmit() }
        } label: {
            ZStack {
                Text(submitTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .opacity(isLoading ? 0 : 1)
                if isLoading { ProgressView().tint(.white) }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(
                Capsule(style: .continuous)
                    .fill(buttonGold)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(isDark ? 0.18 : 0.38), lineWidth: 1)
            )
            .shadow(color: buttonGold.opacity(isDark ? 0.32 : 0.24), radius: 8, y: 3)
        }
        .disabled(isLoading)
        .scaleEffect(isLoading ? 0.98 : 1)
        .animation(.spring(duration: 0.3), value: isLoading)
    }

    private var submitTitle: String {
        switch screen {
        case .landing:   ""
        case .login:     "Login"
        case .signup:    "Create Account"
        case .forgot:    "Send Reset Link"
        case .twofactor: "Verify"
        }
    }

    // MARK: - Passkey Login

    private var passkeyDivider: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(separatorColor)
                .frame(height: 1)
            Text("OR")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
            Rectangle()
                .fill(separatorColor)
                .frame(height: 1)
        }
        .padding(.vertical, 4)
    }

    private var passkeyLoginButton: some View {
        Button {
            focusedField = nil
            _Concurrency.Task { await submitPasskeyLogin() }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "person.badge.key.fill")
                    .font(.body)
                Text("Sign in with Passkey")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(
                Capsule(style: .continuous)
                    .fill(.thinMaterial)
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(separatorColor, lineWidth: 1)
                    }
            )
        }
        .disabled(isLoading)
    }

    // MARK: - Form Link

    @ViewBuilder
    private var formLink: some View {
        switch screen {
        case .landing:
            EmptyView()
        case .login:
            switchRow("Don\u{2019}t have an Account ?", action: "Sign up") { navigateTo(.signup) }
        case .signup:
            switchRow("Already have an Account!", action: "Login") { navigateTo(.login) }
        case .forgot:
            switchRow("Remember your password?", action: "Sign in") { navigateTo(.login) }
        case .twofactor:
            switchRow("", action: "Back to Sign in") { navigateTo(.login) }
        }
    }

    private func switchRow(_ text: String, action: String, handler: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            if !text.isEmpty {
                Text(text).foregroundStyle(.secondary)
            }
            Button(action, action: handler)
                .fontWeight(.semibold)
                .foregroundStyle(accent)
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Underline Input Components

    private func underlineField(
        _ label: String,
        text: Binding<String>,
        icon: String,
        focus: FormField,
        keyboard: UIKeyboardType = .default,
        capitalize: Bool = false,
        content: UITextContentType? = nil,
        submitLabel: SubmitLabel = .next,
        onSubmit: (() -> Void)? = nil
    ) -> some View {
        let isFocused = focusedField == focus
        return VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.footnote.weight(.medium))
                .foregroundStyle(isFocused ? accent : .primary)
                .animation(.easeInOut(duration: 0.15), value: isFocused)

            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.callout)
                    .foregroundStyle(isFocused ? accent : fieldIconColor)
                    .frame(width: 18)
                    .animation(.easeInOut(duration: 0.15), value: isFocused)

                TextField(label.lowercased(), text: text)
                    .font(.body)
                    .keyboardType(keyboard)
                    .textContentType(content)
                    .textInputAutocapitalization(capitalize ? .words : .never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: focus)
                    .submitLabel(submitLabel)
                    .onSubmit { onSubmit?() }
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.thinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isFocused ? accent.opacity(0.75) : separatorColor, lineWidth: isFocused ? 1.4 : 1)
                    }
            )
            .shadow(color: .black.opacity(isDark ? 0.10 : 0.04), radius: 4, y: 2)

        }
    }

    private func underlineSecureField(
        _ label: String,
        text: Binding<String>,
        isVisible: Binding<Bool>,
        icon: String,
        focus: FormField,
        content: UITextContentType = .password,
        submitLabel: SubmitLabel = .next,
        onSubmit: (() -> Void)? = nil
    ) -> some View {
        let isFocused = focusedField == focus
        return VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.footnote.weight(.medium))
                .foregroundStyle(isFocused ? accent : .primary)
                .animation(.easeInOut(duration: 0.15), value: isFocused)

            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.callout)
                    .foregroundStyle(isFocused ? accent : fieldIconColor)
                    .frame(width: 18)
                    .animation(.easeInOut(duration: 0.15), value: isFocused)

                Group {
                    if isVisible.wrappedValue {
                        TextField(label.lowercased(), text: text)
                    } else {
                        SecureField(label.lowercased(), text: text)
                    }
                }
                .font(.body)
                .textContentType(content)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: focus)
                .submitLabel(submitLabel)
                .onSubmit { onSubmit?() }

                Button {
                    let wasFocused = focusedField == focus
                    isVisible.wrappedValue.toggle()
                    if wasFocused {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            focusedField = focus
                        }
                    }
                } label: {
                    Image(systemName: isVisible.wrappedValue ? "eye.slash" : "eye")
                        .font(.subheadline)
                        .foregroundStyle(isFocused ? accent : fieldIconColor)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.thinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isFocused ? accent.opacity(0.75) : separatorColor, lineWidth: isFocused ? 1.4 : 1)
                    }
            )
            .shadow(color: .black.opacity(isDark ? 0.10 : 0.04), radius: 4, y: 2)
        }
    }

    // MARK: - Navigation

    private func navigateTo(_ target: AuthScreen) {
        focusedField = nil
        otpFocused = false
        withAnimation(.spring(duration: 0.5, bounce: 0.15)) {
            screen = target
            errorMessage = ""
            successMessage = ""
        }
        let delay: Double = 0.55
        switch target {
        case .login:     DispatchQueue.main.asyncAfter(deadline: .now() + delay) { focusedField = .email }
        case .signup:    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { focusedField = .firstName }
        case .forgot:    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { focusedField = .email }
        case .twofactor: DispatchQueue.main.asyncAfter(deadline: .now() + 0.6)  { otpFocused = true }
        case .landing:   break
        }
    }

    // MARK: - Actions

    private func showError(_ message: String) {
        withAnimation(.spring(duration: 0.3)) { errorMessage = message }
    }

    private func performSubmit() async {
        switch screen {
        case .landing:   break
        case .login:     await submitLogin()
        case .signup:    await submitSignUp()
        case .forgot:    await submitForgotPassword()
        case .twofactor: await submitTwoFactor()
        }
    }

    private func submitLogin() async {
        guard !email.isEmpty, !password.isEmpty else {
            showError("Please enter both email and password"); return
        }
        isLoading = true; errorMessage = ""
        let result = await interactor.loginWithEmail(email: email, password: password)
        if result.requiresTwoFactor, let userId = result.userId {
            twoFactorUserId = userId
            navigateTo(.twofactor)
        } else if !result.success {
            showError(result.error ?? "Login failed")
        } else {
            promptForQuickUnlockIfNeeded()
        }
        isLoading = false
    }

    private func attemptPasskeyThenLogin() async {
        // Try passkey login automatically; fall through to password form on failure
        isLoading = true
        let result = await interactor.loginWithPasskey()
        isLoading = false

        if result.success {
            promptForQuickUnlockIfNeeded()
        } else {
            // Passkey failed or cancelled — fall through to password login form
            navigateTo(.login)
        }
    }

    private func submitPasskeyLogin() async {
        isLoading = true; errorMessage = ""
        let result = await interactor.loginWithPasskey()
        if result.success {
            promptForQuickUnlockIfNeeded()
        } else if let error = result.error, error != "Passkey sign-in was cancelled." {
            showError(error)
        }
        isLoading = false
    }

    private func submitSignUp() async {
        guard !email.isEmpty, !password.isEmpty, !confirmPassword.isEmpty,
              !firstName.isEmpty, !lastName.isEmpty else {
            showError("Please fill in all fields"); return
        }
        guard password == confirmPassword else {
            showError("Passwords do not match"); return
        }
        isLoading = true; errorMessage = ""
        let result = await interactor.signUp(email: email, password: password, confirmPassword: confirmPassword, firstName: firstName, lastName: lastName)
        if !result.success { showError(result.error ?? "Sign up failed") }
        else { promptForQuickUnlockIfNeeded() }
        isLoading = false
    }

    private func submitForgotPassword() async {
        guard !email.isEmpty else {
            showError("Please enter your email"); return
        }
        isLoading = true; errorMessage = ""; successMessage = ""
        let result = await interactor.forgotPassword(email: email)
        if result.success {
            withAnimation(.spring(duration: 0.3)) {
                successMessage = "If the email exists, a reset link has been sent."
            }
        } else {
            showError(result.error ?? "Request failed")
        }
        isLoading = false
    }

    private func submitTwoFactor() async {
        guard !twoFactorCode.isEmpty else {
            showError("Please enter the verification code"); return
        }
        isLoading = true; errorMessage = ""
        let result = await interactor.verifyTwoFactor(userId: twoFactorUserId, code: twoFactorCode)
        if !result.success { showError(result.error ?? "Invalid code") }
        else { promptForQuickUnlockIfNeeded() }
        isLoading = false
    }

    private func promptForQuickUnlockIfNeeded() {
        guard !hasAskedQuickUnlock else { return }
        showQuickUnlockPrompt = true
    }
}

// MARK: - Previews

#Preview("Light") {
    LandingView()
        .environment(\.injected, .preview)
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    LandingView()
        .environment(\.injected, .preview)
        .preferredColorScheme(.dark)
}
