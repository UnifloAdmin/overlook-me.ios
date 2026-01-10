//
//  SideNavigationView.swift
//  overlook me
//
//  Created by Naresh Chandra on 1/8/26.
//

import SwiftUI

struct SideNavigationView: View {
    @Environment(\.injected) private var container: DIContainer
    @Binding var isPresented: Bool
    let onSelectRoute: (SideNavRoute) -> Void
    
    private var state: AppState { container.appState.state }
    private var interactor: AuthInteractor { container.interactors.authInteractor }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(SIDE_NAV_SECTIONS) { section in
                    Section {
                        ForEach(section.items) { item in
                            Button {
                                isPresented = false
                                DispatchQueue.main.async {
                                    onSelectRoute(item.route)
                                }
                            } label: {
                                navRow(item: item, accent: section.color)
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14))
                        }
                    } header: {
                        Text(section.label)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                            .textCase(nil)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(.compact)
            .navigationTitle("Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) { close() }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { bottomAccountArea }
        }
    }
    
    private func navRow(item: SideNavItem, accent: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.systemImage)
                .font(.system(size: 14, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(accent)
                .frame(width: 20, height: 20)
            
            Text(item.label)
                .font(.callout)
                .foregroundStyle(.primary)
            
            Spacer()
        }
        .padding(.leading, 4)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
    
    private var bottomAccountArea: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                userProfileRow
                logoutIconButton
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .pillBackground()
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }
    
    private var userProfileRow: some View {
        HStack(spacing: 12) {
            if let user = state.auth.user {
                if let pictureURL = user.picture, let url = URL(string: pictureURL) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        defaultAvatar
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                } else {
                    defaultAvatar
                        .frame(width: 40, height: 40)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.name ?? user.email)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    if user.name != nil {
                        Text(user.email)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("Not signed in")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var logoutIconButton: some View {
        Button(action: logout) {
            Image(systemName: "rectangle.portrait.and.arrow.right")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.red)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .disabled(state.auth.isLoading)
        .accessibilityLabel("Sign Out")
    }
    
    private var defaultAvatar: some View {
        Image(systemName: "person.circle.fill")
            .resizable()
            .foregroundColor(.blue)
    }
    
    private func logout() {
        Task {
            await interactor.logout()
            isPresented = false
        }
    }
    
    private func close() {
        isPresented = false
    }
}

// MARK: - Styling

private struct PillBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(Color(.separator).opacity(0.35), lineWidth: 0.5)
                    )
            }
    }
}

private extension View {
    func pillBackground() -> some View {
        modifier(PillBackgroundModifier())
    }
}

// MARK: - Preview

#Preview {
    SideNavigationView(isPresented: .constant(true), onSelectRoute: { _ in })
        .environment(\.injected, .previewAuthenticated)
}
