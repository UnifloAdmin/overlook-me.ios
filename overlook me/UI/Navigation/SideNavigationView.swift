//
//  SideNavigationView.swift
//  overlook me
//
//  Created by Naresh Chandra on 1/8/26.
//

import SwiftUI

struct SideNavigationView: View {
    @Environment(\.injected) private var container: DIContainer
    @Environment(\.dismiss) private var dismiss
    @Binding var isPresented: Bool
    let onSelectRoute: (SideNavRoute) -> Void
    @State private var isSettingsPresented = false
    
    private var state: AppState { container.appState.state }
    private var interactor: AuthInteractor { container.interactors.authInteractor }
    
    var body: some View {
        NavigationStack {
            List {
                // Navigation sections
                ForEach(SIDE_NAV_SECTIONS) { section in
                    Section {
                        ForEach(section.items) { item in
                            navigationRow(item: item, accent: section.color)
                        }
                    } header: {
                        Text(section.label)
                    }
                }
                
                // Account section at bottom
                Section {
                    userProfileRow
                    
                    Button {
                        isSettingsPresented = true
                    } label: {
                        HStack {
                            Label("Settings", systemImage: "gearshape")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: logout) {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(.red)
                    }
                    .disabled(state.auth.isLoading)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Navigate To")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("", systemImage: "xmark") {
                        dismiss()
                    }
                }
            }
            .fullScreenCover(isPresented: $isSettingsPresented) {
                SettingsView()
            }
        }
    }
    
    private func navigationRow(item: SideNavItem, accent: Color) -> some View {
        Button {
            onSelectRoute(item.route)
            isPresented = false
        } label: {
            HStack {
                Label(item.label, systemImage: item.systemImage)
                    .tint(accent)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private var userProfileRow: some View {
        HStack(spacing: 14) {
            if let user = state.auth.user {
                profileImage(for: user)
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.name ?? user.email)
                        .font(.headline)
                        .lineLimit(1)
                    
                    if user.name != nil {
                        Text(user.email)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            } else {
                defaultAvatar
                    .frame(width: 60, height: 60)
                
                Text("Not signed in")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private func profileImage(for user: User) -> some View {
        if let pictureURL = user.picture, let url = URL(string: pictureURL) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                defaultAvatar
            }
        } else {
            defaultAvatar
        }
    }
    
    private var defaultAvatar: some View {
        Image(systemName: "person.circle.fill")
            .resizable()
            .foregroundStyle(.secondary)
    }
    
    private func logout() {
        _Concurrency.Task {
            await interactor.logout()
            isPresented = false
        }
    }
}

// MARK: - Preview

#Preview {
    SideNavigationView(isPresented: .constant(true), onSelectRoute: { _ in })
        .environment(\.injected, .previewAuthenticated)
}
