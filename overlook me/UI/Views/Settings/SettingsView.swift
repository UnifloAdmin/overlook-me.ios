//
//  SettingsView.swift
//  overlook me
//
//  Created by Naresh Chandra on 1/15/26.
//

import SwiftUI

// MARK: - Settings Tab

private enum SettingsTab: String, CaseIterable, Identifiable {
    case security, notifications, account, appearance

    var id: String { rawValue }

    var label: String {
        switch self {
        case .security:      "Security"
        case .notifications: "Notifications"
        case .account:       "Account"
        case .appearance:    "Appearance"
        }
    }

    var icon: String {
        switch self {
        case .security:      "lock.shield"
        case .notifications: "bell.badge"
        case .account:       "person.crop.circle"
        case .appearance:    "paintbrush"
        }
    }

    var color: Color {
        switch self {
        case .security:      Color.wellnessGreen
        case .notifications: .orange
        case .account:       .blue
        case .appearance:    .purple
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: SettingsTab = .security

    var body: some View {
        NavigationStack {
            List {
                // Sidebar menu
                Section {
                    ForEach(SettingsTab.allCases) { tab in
                        settingsRow(tab)
                    }
                } header: {
                    Text("Settings")
                }

                // Security extras
                Section {
                    faceIdRow
                } header: {
                    Text("Quick Toggles")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationDestination(for: SettingsTab.self) { tab in
                settingsDestination(tab)
            }
        }
    }

    // MARK: - Row

    private func settingsRow(_ tab: SettingsTab) -> some View {
        NavigationLink(value: tab) {
            Label {
                Text(tab.label)
                    .font(.body)
            } icon: {
                Image(systemName: tab.icon)
                    .foregroundStyle(tab.color)
            }
        }
    }

    // MARK: - Destination

    @ViewBuilder
    private func settingsDestination(_ tab: SettingsTab) -> some View {
        switch tab {
        case .security:
            SecuritySettingsView()
        case .notifications:
            PlaceholderSettingsView(title: "Notifications", icon: "bell.badge", description: "Manage email, push, and in-app notification preferences.")
        case .account:
            PlaceholderSettingsView(title: "Account", icon: "person.crop.circle", description: "Manage your profile, email, and password.")
        case .appearance:
            PlaceholderSettingsView(title: "Appearance", icon: "paintbrush", description: "Customize theme, layout, and display preferences.")
        }
    }

    // MARK: - Face ID Row

    @AppStorage("isFaceIdDisabled") private var isFaceIdDisabled = false
    @State private var isConsentSheetPresented = false

    private var faceIdRow: some View {
        Toggle(isOn: faceIdBinding) {
            Label {
                Text("Face ID")
                    .font(.body)
            } icon: {
                Image(systemName: "faceid")
                    .foregroundStyle(.secondary)
            }
        }
        .tint(Color.wellnessGreen)
        .sheet(isPresented: $isConsentSheetPresented) {
            FaceIdDisableConsentSheet(
                onConsent: {
                    isFaceIdDisabled = true
                    isConsentSheetPresented = false
                },
                onCancel: {
                    isConsentSheetPresented = false
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private var faceIdBinding: Binding<Bool> {
        Binding(
            get: { !isFaceIdDisabled },
            set: { newValue in
                if newValue { isFaceIdDisabled = false }
                else { isConsentSheetPresented = true }
            }
        )
    }
}

// MARK: - Placeholder Settings View

private struct PlaceholderSettingsView: View {
    let title: String
    let icon: String
    let description: String

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.title3.weight(.semibold))
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Text("Coming soon")
                .font(.caption.weight(.medium))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Capsule().fill(Color(.tertiarySystemGroupedBackground)))
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Face ID Consent Sheet

private struct FaceIdDisableConsentSheet: View {
    let onConsent: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Turning off Face ID?")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.red)
                .padding(.top, 6)

            Text("Disabling Face ID means anyone with access to your device can open the app without biometric verification. Your data will still be protected by your account password, but the app will no longer require Face ID to unlock.")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .padding(.top, 2)

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.borderless)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: onConsent) {
                Text("I consent")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.accentColor, in: Capsule())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .presentationBackground(.ultraThinMaterial)
        .presentationCornerRadius(28)
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environment(\.injected, .previewAuthenticated)
}
