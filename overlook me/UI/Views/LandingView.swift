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
            .offset(y: floating ? -floatRange : floatRange)
            .onAppear {
                guard floatSpeed > 0 else { return }
                withAnimation(
                    .easeInOut(duration: floatSpeed)
                    .repeatForever(autoreverses: true)
                ) {
                    floating = true
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
    @FocusState private var otpFocused: Bool

    private var accent: Color { Color.wellnessGreen }
    private var isDark: Bool { colorScheme == .dark }

    private var waveColor: Color {
        isDark ? Color(red: 0.14, green: 0.38, blue: 0.26) : Color.wellnessGreen
    }

    private var pageBg: Color {
        isDark ? Color(red: 0.07, green: 0.07, blue: 0.08) : .white
    }

    private var cardBg: Color {
        isDark ? Color.white.opacity(0.06) : .white
    }

    private var cardShadow: Color {
        isDark ? .clear : .black.opacity(0.04)
    }

    private var separatorColor: Color {
        isDark ? Color.white.opacity(0.12) : Color.secondary.opacity(0.2)
    }

    private var fieldIconColor: Color {
        isDark ? Color.white.opacity(0.5) : Color.secondary
    }

    private var dividerPipe: Color {
        isDark ? Color.white.opacity(0.15) : Color.secondary.opacity(0.3)
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
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Landing Screen
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var landingContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 12) {
                Text("Welcome")
                    .font(.system(size: 34, weight: .bold))

                Text("Track your wellness journey.\nStay mindful, stay in control.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 40)

            // Continue row
            HStack {
                Spacer()
                Button {
                    navigateTo(.login)
                } label: {
                    HStack(spacing: 10) {
                        Text("Continue")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)

                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(accent)
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 44)
        }
        .transition(.opacity)
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
                        .font(.system(size: 30, weight: .bold))
                        .padding(.horizontal, 28)
                        .padding(.bottom, 28)

                    // Alerts
                    alertBanners
                        .padding(.horizontal, 28)

                    // Form card
                    VStack(alignment: .leading, spacing: 22) {
                        formFields

                        if screen == .login {
                            loginExtras
                        }

                        submitButton
                            .padding(.top, 6)
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(cardBg)
                            .shadow(color: cardShadow, radius: 16, y: 8)
                    )
                    .padding(.horizontal, 20)

                    // Switch link
                    formLink
                        .padding(.top, 24)
                        .padding(.bottom, 40)
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
        case .login:     UIScreen.main.bounds.height * 0.20
        case .signup:    UIScreen.main.bounds.height * 0.12
        case .forgot:    UIScreen.main.bounds.height * 0.20
        case .twofactor: UIScreen.main.bounds.height * 0.20
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
            underlineField("Email", text: $email, icon: "envelope", keyboard: .emailAddress, content: .emailAddress)
            underlineSecureField("Password", text: $password, isVisible: $showPassword, icon: "lock")

        case .signup:
            underlineField("First Name", text: $firstName, icon: "person", capitalize: true, content: .givenName)
            underlineField("Last Name", text: $lastName, icon: "person", capitalize: true, content: .familyName)
            underlineField("Email", text: $email, icon: "envelope", keyboard: .emailAddress, content: .emailAddress)
            underlineSecureField("Password", text: $password, isVisible: $showPassword, icon: "lock", content: .newPassword)
            underlineSecureField("Confirm Password", text: $confirmPassword, isVisible: $showConfirmPassword, icon: "lock.rotation", content: .newPassword)

        case .forgot:
            underlineField("Email", text: $email, icon: "envelope", keyboard: .emailAddress, content: .emailAddress)

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
            _Concurrency.Task { await performSubmit() }
        } label: {
            ZStack {
                Text(submitTitle)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .opacity(isLoading ? 0 : 1)
                if isLoading { ProgressView().tint(.white) }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
        keyboard: UIKeyboardType = .default,
        capitalize: Bool = false,
        content: UITextContentType? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            HStack(spacing: 0) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(fieldIconColor)
                    .frame(width: 24)

                Text("|")
                    .font(.callout)
                    .foregroundStyle(dividerPipe)
                    .padding(.horizontal, 8)

                TextField(label.lowercased(), text: text)
                    .font(.body)
                    .keyboardType(keyboard)
                    .textContentType(content)
                    .textInputAutocapitalization(capitalize ? .words : .never)
                    .autocorrectionDisabled()
            }

            Rectangle()
                .fill(separatorColor)
                .frame(height: 1)
        }
    }

    private func underlineSecureField(
        _ label: String,
        text: Binding<String>,
        isVisible: Binding<Bool>,
        icon: String,
        content: UITextContentType = .password
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            HStack(spacing: 0) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(fieldIconColor)
                    .frame(width: 24)

                Text("|")
                    .font(.callout)
                    .foregroundStyle(dividerPipe)
                    .padding(.horizontal, 8)

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

                Button { isVisible.wrappedValue.toggle() } label: {
                    Image(systemName: isVisible.wrappedValue ? "eye.slash" : "eye")
                        .font(.subheadline)
                        .foregroundStyle(fieldIconColor)
                }
                .buttonStyle(.plain)
            }

            Rectangle()
                .fill(separatorColor)
                .frame(height: 1)
        }
    }

    // MARK: - Navigation

    private func navigateTo(_ target: AuthScreen) {
        withAnimation(.spring(duration: 0.5, bounce: 0.15)) {
            screen = target
            errorMessage = ""
            successMessage = ""
        }
        if target == .twofactor {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { otpFocused = true }
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
        isLoading = false
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
