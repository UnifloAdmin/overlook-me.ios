//
//  SecuritySettingsView.swift
//  overlook me
//
//  Created by Naresh Chandra on 2/17/26.
//

import SwiftUI
import UIKit

// MARK: - Known Authenticator Apps

private struct AuthApp: Identifiable {
    let id: String
    let name: String
    let icon: String
    let scheme: String
    let otpauthPrefix: String?
    let storeURL: String

    static let all: [AuthApp] = [
        AuthApp(id: "google",    name: "Google Authenticator", icon: "g.circle.fill",  scheme: "googleauthenticator", otpauthPrefix: "googleauthenticator", storeURL: "https://apps.apple.com/app/id388497605"),
        AuthApp(id: "microsoft", name: "Microsoft Authenticator", icon: "m.circle.fill", scheme: "msauth",  otpauthPrefix: "msauth",  storeURL: "https://apps.apple.com/app/id983156458"),
        AuthApp(id: "duo",       name: "Duo Mobile",          icon: "d.circle.fill",  scheme: "duomobile",           otpauthPrefix: nil,       storeURL: "https://apps.apple.com/app/id422663827"),
        AuthApp(id: "authy",     name: "Authy",               icon: "a.circle.fill",  scheme: "authy",               otpauthPrefix: nil,       storeURL: "https://apps.apple.com/app/id494168017"),
        AuthApp(id: "1password", name: "1Password",           icon: "key.fill",       scheme: "onepassword",         otpauthPrefix: "onepassword", storeURL: "https://apps.apple.com/app/id1511601750"),
    ]
}

// MARK: - Security Settings View

struct SecuritySettingsView: View {
    @Environment(\.injected) private var container: DIContainer
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    private var interactor: AuthInteractor { container.interactors.authInteractor }
    private var user: User? { container.appState.state.auth.user }

    @State private var isLoading = false
    @State private var errorMessage = ""

    // Email
    @State private var emailVerified: Bool?
    @State private var resendingEmail = false

    // 2FA status
    @State private var tfaStatus: TwoFactorStatusInfo?
    @State private var devices: [AuthenticatorDevice] = []

    // 2FA setup (single unified flow)
    @State private var isSettingUp = false
    @State private var sharedKey = ""
    @State private var selectedApp: AuthApp?
    @State private var verifyCode = ""
    @State private var recoveryCodes: [String] = []
    @State private var copiedCodes = false
    @State private var showRecovery = false

    // 2FA disable
    @State private var isDisabling = false
    @State private var disableCode = ""

    // Detected apps
    @State private var installedApps: [AuthApp] = []

    @FocusState private var codeFieldFocused: Bool

    private var isDark: Bool { colorScheme == .dark }
    private var accent: Color { Color.wellnessGreen }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if !errorMessage.isEmpty { errorBanner }

                if showRecovery {
                    recoverySection
                } else if isSettingUp {
                    setupFlow
                } else if isDisabling {
                    disableSection
                } else {
                    emailSection
                    twoFactorSection
                    if tfaStatus?.enabled == true { devicesSection }
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Security")
        .navigationBarTitleDisplayMode(.large)
        .task { await loadStatus() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && isSettingUp && selectedApp != nil {
                codeFieldFocused = true
            }
        }
    }

    // MARK: - Load Status

    private func loadStatus() async {
        async let emailCheck = interactor.checkEmailStatus()
        async let tfaCheck = interactor.getFullTwoFactorStatus()
        async let devicesCheck = interactor.getAuthenticatorDevices()

        emailVerified = await emailCheck
        tfaStatus = await tfaCheck
        devices = await devicesCheck
    }

    // MARK: - Error Banner

    private var errorBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
            Text(errorMessage).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
            Button { withAnimation { errorMessage = "" } } label: {
                Image(systemName: "xmark").font(.caption2.bold()).foregroundStyle(.tertiary)
            }.buttonStyle(.plain)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.red.opacity(isDark ? 0.15 : 0.08)))
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Email Section
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var emailSection: some View {
        card {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("Email Verification", systemImage: "envelope.badge").font(.headline)
                    Spacer()
                    pill(emailVerified ?? false)
                }

                if let user {
                    Text(user.email).font(.subheadline).foregroundStyle(.secondary)
                }

                if emailVerified == false {
                    Text("Verify your email to secure your account and receive important notifications.")
                        .font(.caption).foregroundStyle(.secondary)

                    primaryButton(resendingEmail ? "Sending..." : "Resend Verification Email", loading: resendingEmail) {
                        _Concurrency.Task { await resendEmail() }
                    }
                }
            }
        }
    }

    private func resendEmail() async {
        resendingEmail = true
        let result = await interactor.resendVerificationEmail()
        if !result.success { withAnimation { errorMessage = result.error ?? "Failed to send" } }
        resendingEmail = false
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Two-Factor Section (Idle)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var twoFactorSection: some View {
        card {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("Two-Factor Authentication", systemImage: "lock.shield").font(.headline)
                    Spacer()
                    pill(tfaStatus?.enabled ?? false)
                }

                if tfaStatus?.enabled == true {
                    if let at = tfaStatus?.enabledAt { infoRow("calendar", "Enabled", formatDate(at)) }
                    if let c = tfaStatus?.recoveryCodesLeft { infoRow("key.fill", "Recovery codes", "\(c)") }

                    Button {
                        withAnimation(.spring(duration: 0.4)) { isDisabling = true }
                    } label: {
                        Text("Disable Two-Factor")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity).frame(height: 44)
                            .foregroundStyle(.red)
                            .background(Color.red.opacity(isDark ? 0.15 : 0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                } else {
                    Text("Add an extra layer of security with an authenticator app.")
                        .font(.caption).foregroundStyle(.secondary)

                    primaryButton("Enable Two-Factor", loading: isLoading) {
                        _Concurrency.Task { await beginSetup() }
                    }
                }
            }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Setup Flow (unified)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var setupFlow: some View {
        card {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack {
                    Label("Set up authenticator", systemImage: "shield.checkered").font(.headline)
                    Spacer()
                    Button { cancelSetup() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }.buttonStyle(.plain)
                }

                // Step 1: Pick app
                VStack(alignment: .leading, spacing: 12) {
                    stepLabel(1, "Choose your authenticator app", done: selectedApp != nil)

                    if installedApps.isEmpty {
                        noAppsDetected
                    } else {
                        ForEach(installedApps) { app in
                            appRow(app)
                        }
                    }
                }

                // Step 2: Verify (shown after app was opened)
                if selectedApp != nil {
                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        stepLabel(2, "Enter the code from \(selectedApp!.name)", done: false)

                        TextField("000000", text: $verifyCode)
                            .keyboardType(.numberPad)
                            .focused($codeFieldFocused)
                            .font(.system(.title, design: .monospaced, weight: .bold))
                            .tracking(8)
                            .multilineTextAlignment(.center)
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(isDark ? Color.white.opacity(0.06) : Color(.tertiarySystemGroupedBackground))
                            )
                            .onChange(of: verifyCode) { _, val in
                                let cleaned = String(val.prefix(6).filter(\.isNumber))
                                if cleaned != val { verifyCode = cleaned }
                                if cleaned.count == 6 {
                                    _Concurrency.Task { await confirmEnable() }
                                }
                            }

                        if isLoading {
                            HStack(spacing: 8) {
                                ProgressView().controlSize(.small)
                                Text("Verifying...").font(.caption).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }

                // Manual key (always available, collapsed)
                DisclosureGroup {
                    HStack {
                        Text(sharedKey)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Button {
                            UIPasteboard.general.string = sharedKey
                            copiedCodes = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copiedCodes = false }
                        } label: {
                            Image(systemName: copiedCodes ? "checkmark" : "doc.on.doc")
                                .font(.caption).foregroundStyle(copiedCodes ? accent : .secondary)
                        }.buttonStyle(.plain)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(isDark ? Color.white.opacity(0.04) : Color(.tertiarySystemGroupedBackground)))
                    .padding(.top, 6)
                } label: {
                    Text("Can\u{2019}t open the app? Copy key manually")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
        }
    }

    // MARK: - App Row

    private func appRow(_ app: AuthApp) -> some View {
        let picked = selectedApp?.id == app.id

        return Button { openApp(app) } label: {
            HStack(spacing: 12) {
                Image(systemName: app.icon)
                    .font(.title3)
                    .foregroundStyle(picked ? .white : accent)
                    .frame(width: 36, height: 36)
                    .background(picked ? accent : accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                Text(app.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                Spacer()

                if picked {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(accent)
                } else {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(picked ? accent.opacity(isDark ? 0.12 : 0.05) : (isDark ? Color.white.opacity(0.06) : Color(.tertiarySystemGroupedBackground)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(picked ? accent.opacity(0.3) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - No Apps Detected

    private var noAppsDetected: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("No authenticator apps found", systemImage: "exclamationmark.circle")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.orange)

            Text("Install one, then tap Refresh.")
                .font(.caption).foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AuthApp.all) { app in
                        Button {
                            if let url = URL(string: app.storeURL) { UIApplication.shared.open(url) }
                        } label: {
                            Label(app.name, systemImage: app.icon)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(accent)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(accent.opacity(0.1), in: Capsule())
                        }.buttonStyle(.plain)
                    }
                }
            }

            Button { detectInstalledApps() } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .font(.caption.weight(.semibold)).foregroundStyle(accent)
            }.buttonStyle(.plain)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.orange.opacity(isDark ? 0.08 : 0.05)))
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Recovery Codes
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var recoverySection: some View {
        card {
            VStack(alignment: .leading, spacing: 20) {
                Label {
                    Text("Two-Factor Enabled")
                } icon: {
                    Image(systemName: "checkmark.shield.fill").foregroundStyle(accent)
                }
                .font(.headline)

                Text("Save these recovery codes somewhere safe. You\u{2019}ll need them if you lose access to your authenticator.")
                    .font(.subheadline).foregroundStyle(.secondary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(recoveryCodes, id: \.self) { code in
                        Text(code)
                            .font(.system(.subheadline, design: .monospaced, weight: .medium))
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(isDark ? Color.white.opacity(0.06) : Color(.tertiarySystemGroupedBackground)))
                    }
                }

                Button {
                    UIPasteboard.general.string = recoveryCodes.joined(separator: "\n")
                    copiedCodes = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copiedCodes = false }
                } label: {
                    Label(copiedCodes ? "Copied" : "Copy All Codes", systemImage: copiedCodes ? "checkmark" : "doc.on.doc")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity).frame(height: 44)
                        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .foregroundStyle(.primary)
                }

                primaryButton("Done", loading: false) {
                    withAnimation(.spring(duration: 0.4)) {
                        showRecovery = false
                        isSettingUp = false
                    }
                    _Concurrency.Task { await loadStatus() }
                }
            }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Disable Section
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var disableSection: some View {
        card {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Label("Disable Two-Factor", systemImage: "lock.open")
                        .font(.headline).foregroundStyle(.red)
                    Spacer()
                    Button { withAnimation(.spring(duration: 0.4)) { isDisabling = false; disableCode = "" } } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3).symbolRenderingMode(.hierarchical).foregroundStyle(.secondary)
                    }.buttonStyle(.plain)
                }

                Text("Enter the code from your authenticator to confirm.")
                    .font(.subheadline).foregroundStyle(.secondary)

                TextField("000000", text: $disableCode)
                    .keyboardType(.numberPad)
                    .font(.system(.title, design: .monospaced, weight: .bold))
                    .tracking(8)
                    .multilineTextAlignment(.center)
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(isDark ? Color.white.opacity(0.06) : Color(.tertiarySystemGroupedBackground)))
                    .onChange(of: disableCode) { _, val in
                        disableCode = String(val.prefix(6).filter(\.isNumber))
                    }

                HStack(spacing: 12) {
                    Button("Cancel") {
                        withAnimation(.spring(duration: 0.4)) { isDisabling = false; disableCode = "" }
                    }
                    .frame(maxWidth: .infinity).frame(height: 44)
                    .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .foregroundStyle(.primary).font(.subheadline.weight(.medium))

                    Button {
                        _Concurrency.Task { await confirmDisable() }
                    } label: {
                        HStack(spacing: 6) {
                            if isLoading { ProgressView().controlSize(.small).tint(.white) }
                            Text("Disable").font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity).frame(height: 44)
                        .background(Color.red, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .foregroundStyle(.white)
                    }
                    .disabled(disableCode.count < 6 || isLoading)
                }
            }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Devices Section
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var devicesSection: some View {
        card {
            VStack(alignment: .leading, spacing: 16) {
                Label("Connected Devices", systemImage: "iphone.gen3").font(.headline)

                if devices.isEmpty {
                    Text("No devices registered.").font(.subheadline).foregroundStyle(.tertiary)
                } else {
                    ForEach(devices) { device in
                        deviceRow(device)
                        if device.id != devices.last?.id { Divider() }
                    }
                }
            }
        }
    }

    private func deviceRow(_ device: AuthenticatorDevice) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "iphone.gen3").font(.title3).foregroundStyle(.secondary).frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(device.deviceName ?? "Unknown Device").font(.subheadline.weight(.medium))
                HStack(spacing: 8) {
                    if let app = device.authenticatorApp { Text(app).font(.caption).foregroundStyle(.secondary) }
                    if let date = device.registeredAt { Text(formatDate(date)).font(.caption).foregroundStyle(.tertiary) }
                }
            }
            Spacer()
            if device.isActive == true {
                Text("Active").font(.caption2.weight(.semibold)).foregroundStyle(accent)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(accent.opacity(0.12), in: Capsule())
            }
            Button { _Concurrency.Task { await removeDevice(device.id) } } label: {
                Image(systemName: "trash").font(.subheadline).foregroundStyle(.red.opacity(0.7))
            }.buttonStyle(.plain)
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Actions
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func detectInstalledApps() {
        installedApps = AuthApp.all.filter { app in
            guard let url = URL(string: "\(app.scheme)://") else { return false }
            return UIApplication.shared.canOpenURL(url)
        }
    }

    private func openApp(_ app: AuthApp) {
        selectedApp = app
        let email = user?.email ?? "user"
        let encoded = email.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? email
        let base = "otpauth://totp/OverlookMe:\(encoded)?secret=\(sharedKey)&issuer=OverlookMe"
        let uri = app.otpauthPrefix.map { base.replacingOccurrences(of: "otpauth://", with: "\($0)://") } ?? base

        guard let url = URL(string: uri) else { return }
        UIApplication.shared.open(url)
    }

    private func beginSetup() async {
        isLoading = true; errorMessage = ""
        let result = await interactor.setupTwoFactor()
        if result.success, let key = result.sharedKey {
            sharedKey = key
            detectInstalledApps()
            withAnimation(.spring(duration: 0.4)) { isSettingUp = true }
        } else {
            withAnimation { errorMessage = result.error ?? "Setup failed" }
        }
        isLoading = false
    }

    private func confirmEnable() async {
        isLoading = true; errorMessage = ""
        let deviceName = UIDevice.current.name
        let appName = selectedApp?.name ?? "Authenticator"
        let result = await interactor.enableTwoFactor(code: verifyCode, deviceName: deviceName, authenticatorApp: appName, platform: "iOS")
        if result.success {
            recoveryCodes = result.recoveryCodes ?? []
            verifyCode = ""
            withAnimation(.spring(duration: 0.4)) { showRecovery = true }
        } else {
            verifyCode = ""
            withAnimation { errorMessage = result.error ?? "Invalid code" }
        }
        isLoading = false
    }

    private func confirmDisable() async {
        isLoading = true; errorMessage = ""
        let result = await interactor.disableTwoFactor(code: disableCode)
        if result.success {
            disableCode = ""
            withAnimation(.spring(duration: 0.4)) { isDisabling = false }
            await loadStatus()
        } else {
            withAnimation { errorMessage = result.error ?? "Failed to disable" }
        }
        isLoading = false
    }

    private func removeDevice(_ deviceId: String) async {
        let result = await interactor.removeAuthenticatorDevice(deviceId: deviceId)
        if result.success { withAnimation { devices.removeAll { $0.id == deviceId } } }
        else { withAnimation { errorMessage = result.error ?? "Failed to remove device" } }
    }

    private func cancelSetup() {
        withAnimation(.spring(duration: 0.4)) {
            isSettingUp = false
            selectedApp = nil
            verifyCode = ""
            sharedKey = ""
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Shared Components
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func card<C: View>(@ViewBuilder content: () -> C) -> some View {
        content()
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
    }

    private func pill(_ on: Bool) -> some View {
        Text(on ? "Enabled" : "Disabled")
            .font(.caption2.weight(.bold))
            .foregroundStyle(on ? accent : .orange)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background((on ? accent : Color.orange).opacity(0.12), in: Capsule())
    }

    private func infoRow(_ icon: String, _ label: String, _ value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.subheadline).foregroundStyle(.secondary).frame(width: 20)
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.subheadline.weight(.medium))
        }
    }

    private func stepLabel(_ n: Int, _ text: String, done: Bool) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(done ? accent : accent.opacity(0.15)).frame(width: 26, height: 26)
                if done {
                    Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white)
                } else {
                    Text("\(n)").font(.caption.bold()).foregroundStyle(accent)
                }
            }
            Text(text).font(.subheadline.weight(.medium))
        }
    }

    private func primaryButton(_ title: String, loading: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if loading { ProgressView().controlSize(.small) }
                Text(title).font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity).frame(height: 44)
            .background(accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .foregroundStyle(.white)
        }
        .disabled(loading)
    }

    private func formatDate(_ iso: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let d = f.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) else { return iso }
        let df = DateFormatter(); df.dateStyle = .medium; df.timeStyle = .short
        return df.string(from: d)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SecuritySettingsView()
            .environment(\.injected, .previewAuthenticated)
    }
}
