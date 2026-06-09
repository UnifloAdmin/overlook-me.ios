//
//  SideNavigationView.swift
//  overlook me
//

import SwiftUI

struct SideNavigationView: View {
    @Environment(\.injected) private var container: DIContainer
    @Environment(\.dismiss) private var dismiss
    let onSelectRoute: (SideNavRoute) -> Void
    @State private var searchText = ""
    @State private var isSettingsPresented = false

    private var state: AppState { container.appState.state }
    private var interactor: AuthInteractor { container.interactors.authInteractor }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredSections) { section in
                    Section {
                        ForEach(section.items) { item in
                            Button { onSelectRoute(item.route) } label: {
                                navRowLabel(item.label, systemImage: item.systemImage)
                            }
                            .listRowBackground(Kalshi.bg)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        }
                    } header: {
                        sectionHeader(section.label)
                    }
                }

                Section {
                    userProfileRow

                    Button { isSettingsPresented = true } label: {
                        navRowLabel("Settings", systemImage: "gearshape")
                    }
                    .listRowBackground(Kalshi.bg)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))

                    Button(role: .destructive) { logout() } label: {
                        navRowLabel("Sign Out", systemImage: "rectangle.portrait.and.arrow.right", tint: Kalshi.red)
                    }
                    .disabled(state.auth.isLoading)
                    .listRowBackground(Kalshi.bg)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                } header: {
                    sectionHeader("Account")
                }
            }
            .listStyle(.plain)
            .listSectionSpacing(.compact)
            .environment(\.defaultMinListRowHeight, 0)
            .scrollContentBackground(.hidden)
            .background(Kalshi.bg)
            .navigationTitle("overlook me")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 28, height: 28)
                            .glassEffect(.regular, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .fullScreenCover(isPresented: $isSettingsPresented) {
                SettingsView()
            }
        }
        .searchable(text: $searchText, placement: .automatic, prompt: "Search sections")
    }

    // MARK: - Row builders

    private func navRowLabel(_ label: String, systemImage: String, tint: Color? = nil) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 18, alignment: .center)
                .foregroundStyle(tint ?? Kalshi.textSecondary)
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .tracking(-0.15)
                .foregroundStyle(tint ?? Kalshi.textPrimary)
            Spacer()
        }
        .frame(minHeight: 28)
        .contentShape(Rectangle())
    }

    private func sectionHeader(_ label: String) -> some View {
        Text(label)
            .kalshiEyebrow()
    }

    // MARK: - Account row

    private var userProfileRow: some View {
        HStack(spacing: 10) {
            Group {
                if let user = state.auth.user {
                    profileImage(for: user)
                        .frame(width: 30, height: 30)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Kalshi.inputBorder, lineWidth: 1))
                } else {
                    defaultAvatar.frame(width: 30, height: 30)
                }
            }

            if let user = state.auth.user {
                VStack(alignment: .leading, spacing: 1) {
                    Text(user.name ?? user.email)
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(-0.13)
                        .foregroundStyle(Kalshi.textPrimary)
                        .lineLimit(1)
                    if user.name != nil {
                        Text(user.email)
                            .kalshiSecondary()
                            .lineLimit(1)
                    }
                }
            } else {
                Text("Not signed in")
                    .kalshiSecondary()
            }
            Spacer()
        }
        .listRowBackground(Kalshi.bg)
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
    }

    @ViewBuilder
    private func profileImage(for user: User) -> some View {
        if let pictureURL = user.picture, let url = URL(string: pictureURL) {
            AsyncImage(url: url) { $0.resizable().scaledToFill() } placeholder: { defaultAvatar }
        } else {
            defaultAvatar
        }
    }

    private var defaultAvatar: some View {
        Image(systemName: "person.circle.fill")
            .resizable()
            .foregroundStyle(Kalshi.textMuted)
    }

    private func logout() {
        _Concurrency.Task { await interactor.logout() }
    }

    // MARK: - Filtering

    private var filteredSections: [SideNavSection] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return SIDE_NAV_SECTIONS }
        return SIDE_NAV_SECTIONS.compactMap { section in
            let matches = section.items.filter { $0.label.localizedCaseInsensitiveContains(query) }
            return matches.isEmpty ? nil : SideNavSection(id: section.id, label: section.label, items: matches)
        }
    }
}

// MARK: - Preview

#Preview {
    SideNavigationView(onSelectRoute: { _ in })
        .environment(\.injected, .previewAuthenticated)
}
