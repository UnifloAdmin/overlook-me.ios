//
//  SideNavigationView.swift
//  overlook me
//
//  Created by Naresh Chandra on 1/8/26.
//

import SwiftUI

struct SideNavigationView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.injected) private var container: DIContainer
    @Binding var isPresented: Bool
    @Binding var searchText: String
    let onSelectRoute: (SideNavRoute) -> Void
    @State private var isSettingsPresented = false
    @State private var appeared = false
    
    private var state: AppState { container.appState.state }
    private var interactor: AuthInteractor { container.interactors.authInteractor }
    
    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // MARK: - Sections with item cards
                    ForEach(Array(filteredSections.enumerated()), id: \.element.id) { sectionIdx, section in
                        sectionBlock(section: section, sectionIndex: sectionIdx)
                    }
                    
                    // MARK: - Account Card
                    accountCard
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .padding(.bottom, 32)
                }
            }
            .background(kalshiSurface.ignoresSafeArea())
            .navigationTitle("overlook me")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                withAnimation(.spring(duration: 0.5, bounce: 0.12).delay(0.05)) {
                    appeared = true
                }
            }
            .onDisappear { appeared = false }
            .fullScreenCover(isPresented: $isSettingsPresented) {
                SettingsView()
            }
        }
    }
    
    // MARK: - Section Block
    
    private func sectionBlock(section: SideNavSection, sectionIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header
            Text(section.label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(1.0)
                .foregroundStyle(kalshiTertiary)
                .padding(.horizontal, 16)
                .padding(.top, sectionIndex == 0 ? 0 : 14)
            
            if section.items.count == 1, let item = section.items.first {
                // Single item → full width
                let globalIndex = globalCardIndex(sectionIndex: sectionIndex, itemIndex: 0)
                itemCard(item: item, section: section, index: globalIndex)
                    .padding(.horizontal, 16)
            } else {
                // Multiple items → 2-column grid
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Array(section.items.enumerated()), id: \.element.id) { itemIdx, item in
                        let globalIndex = globalCardIndex(sectionIndex: sectionIndex, itemIndex: itemIdx)
                        itemCard(item: item, section: section, index: globalIndex)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    // MARK: - Item Card
    
    private func itemCard(item: SideNavItem, section: SideNavSection, index: Int) -> some View {
        Button {
            onSelectRoute(item.route)
        } label: {
            ZStack(alignment: .bottomLeading) {
                // Background gradient — per-item unique color
                LinearGradient(
                    colors: [item.gradientTop, item.gradientBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Shine overlay for depth
                LinearGradient(
                    colors: [.white.opacity(0.15), .clear, .black.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Large decorative SF Symbol icon
                Image(systemName: item.systemImage)
                    .font(.system(size: 42, weight: .light))
                    .foregroundStyle(.white.opacity(0.25))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, 10)
                    .padding(.trailing, 10)
                
                // Inner glow border
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.35), .white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
                
                // Label at bottom-left
                Text(item.label)
                    .font(.system(size: 14, weight: .bold))
                    .tracking(-0.2)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
                    .padding(12)
            }
            .frame(height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(CardButtonStyle())
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 14)
        .animation(
            .spring(duration: 0.4, bounce: 0.1).delay(Double(index) * 0.025),
            value: appeared
        )
    }
    
    // MARK: - Account Card
    
    private var accountCard: some View {
        VStack(spacing: 0) {
            userProfileRow
            
            Divider().overlay(kalshiDivider)
                .padding(.leading, 60)
            
            accountActionRow(
                title: "Settings",
                icon: "gearshape",
                iconColor: kalshiPrimary
            ) {
                isSettingsPresented = true
            }
            
            Divider().overlay(kalshiDivider)
                .padding(.leading, 60)
            
            accountActionRow(
                title: "Sign Out",
                icon: "rectangle.portrait.and.arrow.right",
                iconColor: Color(hex: "#dc2626")
            ) {
                logout()
            }
            .disabled(state.auth.isLoading)
        }
        .padding(.vertical, 12)
        .glassEffect(.regular, in: .rect(cornerRadius: 18, style: .continuous))
    }
    
    private func accountActionRow(
        title: String,
        icon: String,
        iconColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 30, height: 30)
                    .background(kalshiHover)
                    .clipShape(Circle())
                
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(-0.2)
                    .foregroundStyle(kalshiPrimary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(kalshiTertiary)
            }
            .frame(height: 44)
            .padding(.horizontal, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private var userProfileRow: some View {
        HStack(spacing: 12) {
            if let user = state.auth.user {
                profileImage(for: user)
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(user.name ?? user.email)
                        .font(.system(size: 14, weight: .semibold))
                        .tracking(-0.2)
                        .foregroundStyle(kalshiPrimary)
                        .lineLimit(1)
                    
                    if user.name != nil {
                        Text(user.email)
                            .font(.system(size: 10, weight: .medium))
                            .tracking(0.4)
                            .foregroundStyle(kalshiMuted)
                            .textCase(.uppercase)
                            .lineLimit(1)
                    }
                }
            } else {
                defaultAvatar
                    .frame(width: 40, height: 40)
                
                Text("Not signed in")
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(-0.2)
                    .foregroundStyle(kalshiMuted)
            }
        }
        .padding(.horizontal, 14)
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
            .foregroundStyle(kalshiMuted)
    }
    
    private func logout() {
        _Concurrency.Task {
            await interactor.logout()
        }
    }
    
    // MARK: - Helper
    
    private func globalCardIndex(sectionIndex: Int, itemIndex: Int) -> Int {
        var count = 0
        for i in 0..<sectionIndex {
            count += filteredSections[i].items.count
        }
        return count + itemIndex
    }
    
    // MARK: - Design Tokens
    
    private var kalshiSurface: Color { colorScheme == .dark ? Color(hex: "#000000") : Color(hex: "#ffffff") }
    private var kalshiDivider: Color { colorScheme == .dark ? Color(hex: "#27272a") : Color(hex: "#f4f4f5") }
    private var kalshiHover: Color { colorScheme == .dark ? Color(hex: "#18181b") : Color(hex: "#fafafa") }
    private var kalshiPrimary: Color { colorScheme == .dark ? Color(hex: "#ffffff") : Color(hex: "#09090b") }
    private var kalshiMuted: Color { colorScheme == .dark ? Color(hex: "#a1a1aa") : Color(hex: "#71717a") }
    private var kalshiTertiary: Color { colorScheme == .dark ? Color(hex: "#71717a") : Color(hex: "#a1a1aa") }
    
    // MARK: - Filtered Sections
    
    private var filteredSections: [SideNavSection] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return SIDE_NAV_SECTIONS }
        
        return SIDE_NAV_SECTIONS.compactMap { section in
            let matches = section.items.filter { item in
                item.label.localizedCaseInsensitiveContains(query)
            }
            guard !matches.isEmpty else { return nil }
            return SideNavSection(
                id: section.id,
                label: section.label,
                color: section.color,
                gradientTop: section.gradientTop,
                gradientBottom: section.gradientBottom,
                heroIcon: section.heroIcon,
                items: matches
            )
        }
    }
}

// MARK: - Card Button Style

private struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .brightness(configuration.isPressed ? -0.06 : 0)
            .animation(.spring(duration: 0.2, bounce: 0.25), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    SideNavigationView(
        isPresented: .constant(true),
        searchText: .constant(""),
        onSelectRoute: { _ in }
    )
    .environment(\.injected, .previewAuthenticated)
}
