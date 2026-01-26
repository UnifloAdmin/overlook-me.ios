//
//  SettingsView.swift
//  overlook me
//
//  Created by Naresh Chandra on 1/15/26.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isFaceIdDisabled") private var isFaceIdDisabled = false
    @State private var isConsentSheetPresented = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Settings")
                        .font(.system(size: 28, weight: .bold, design: .default))
                        .foregroundStyle(.primary)

                    Text("Personalize your experience and manage preferences.")
                        .font(.system(size: 15, weight: .regular, design: .default))
                        .foregroundStyle(.secondary)

                    SettingsSection(title: "Security") {
                        Toggle(isOn: faceIdEnabledBinding) {
                            HStack(spacing: 10) {
                                Image(systemName: "faceid")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                Text("Face ID")
                                    .font(.system(size: 16, weight: .semibold, design: .default))
                                    .foregroundStyle(.primary)
                            }
                        }
                            .tint(.accentColor)
                            .padding(14)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
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
    }

    private var faceIdEnabledBinding: Binding<Bool> {
        Binding(
            get: { !isFaceIdDisabled },
            set: { newValue in
                if newValue {
                    isFaceIdDisabled = false
                } else {
                    isConsentSheetPresented = true
                }
            }
        )
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .default))
                .foregroundStyle(.primary)

            content
        }
    }
}

private struct FaceIdDisableConsentSheet: View {
    let onConsent: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Turning off Face ID?")
                .font(.system(size: 24, weight: .bold, design: .default))
                .foregroundStyle(.red)
                .padding(.top, 6)

            Text(loremIpsum)
                .font(.system(size: 15, weight: .regular, design: .default))
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
                        .font(.system(size: 28, weight: .regular))
                        .foregroundStyle(.secondary)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.borderless)
            }
        }
        .safeAreaInset(edge: .bottom) {
            GeometryReader { proxy in
                Button(action: onConsent) {
                    Text("I consent")
                        .font(.system(size: 17, weight: .semibold, design: .default))
                        .foregroundStyle(.white)
                        .frame(width: proxy.size.width * 0.9, height: 52)
                        .background(Color.accentColor)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(height: 64)
            .padding(.bottom, 12)
        }
        .presentationBackground(.ultraThinMaterial)
        .presentationCornerRadius(28)
    }
}

private let loremIpsum = """
Lorem ipsum dolor sit amet, consectetur adipiscing elit. Integer nec risus sit amet orci mollis tincidunt. Vivamus blandit, mauris in porta pulvinar, odio magna commodo justo, sed finibus lacus neque non tortor. Curabitur faucibus, lacus at blandit faucibus, lectus nulla eleifend tortor, sit amet auctor nibh neque at enim. Aenean tempus sodales velit, vel facilisis libero finibus at. Sed vitae justo non lacus ultricies viverra. Proin vitae nisi ut nisl rhoncus maximus. Morbi id nibh id risus convallis laoreet. Aliquam erat volutpat. Quisque at mauris nec metus tristique lacinia. Suspendisse potenti. Fusce euismod, ligula quis viverra sollicitudin, risus sem maximus nulla, non semper justo lectus a ligula. Donec ac dolor dolor. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas.
"""

#Preview {
    SettingsView()
}
