//
//  SideNavigationView.swift
//  overlook me
//
//  Created by Naresh Chandra on 1/8/26.
//

import SwiftUI
import UIKit

struct SideNavigationView: View {
    @Environment(\.injected) private var container: DIContainer
    @Environment(\.dismiss) private var dismiss
    @Binding var isPresented: Bool
    let onSelectRoute: (SideNavRoute) -> Void
    
    private var state: AppState { container.appState.state }
    private var interactor: AuthInteractor { container.interactors.authInteractor }
    @Environment(\.openURL) private var openURL
    
    private let columns = [
        GridItem(.flexible(minimum: 60, maximum: 90), spacing: 12),
        GridItem(.flexible(minimum: 60, maximum: 90), spacing: 12),
        GridItem(.flexible(minimum: 60, maximum: 90), spacing: 12),
        GridItem(.flexible(minimum: 60, maximum: 90), spacing: 12)
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Manually render each section
                    ForEach(0..<SIDE_NAV_SECTIONS.count, id: \.self) { sectionIndex in
                        sectionView(at: sectionIndex)
                    }
                    
                    // User auth at the bottom
                    VStack(spacing: 16) {
                        Divider()
                            .padding(.horizontal, 20)
                        
                        HStack(spacing: 12) {
                            userProfileRow
                            Spacer()
                            settingsIconButton
                            logoutIconButton
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                }
                .padding(.top, 8)
            }
            .navigationTitle("Navigate To")
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
        }
    }
    
    private func sectionView(at index: Int) -> some View {
        let section = SIDE_NAV_SECTIONS[index]
        return VStack(alignment: .leading, spacing: 12) {
            // Section header
            Text(section.label)
                .font(.system(size: 20, weight: .semibold, design: .default))
                .foregroundStyle(.primary)
                .padding(.horizontal, 20)
            
            // Grid of items using index-based iteration
            let itemsGrid = LazyVGrid(columns: columns, spacing: 12) {
                ForEach(0..<section.items.count, id: \.self) { itemIndex in
                    let item = section.items[itemIndex]
                    Button {
                        onSelectRoute(item.route)
                        isPresented = false
                    } label: {
                        moduleCard(item: item, accent: section.color)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            
            itemsGrid
        }
    }
    
    private func moduleCard(item: SideNavItem, accent: Color) -> some View {
        VStack(alignment: .center, spacing: 8) {
            // Icon without background
            Image(systemName: item.systemImage)
                .font(.system(size: 28, weight: .regular, design: .default))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(accent)
                .frame(width: 56, height: 56)
            
            // Label with fixed height
            Text(item.label)
                .font(.system(size: 14, weight: .medium, design: .default))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(height: 36)
                .fixedSize(horizontal: false, vertical: false)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .padding(.vertical, 6)
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
                    .frame(width: 42, height: 42)
                    .clipShape(Circle())
                } else {
                    defaultAvatar
                        .frame(width: 42, height: 42)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(user.name ?? user.email)
                        .font(.system(size: 16, weight: .medium, design: .default))
                        .lineLimit(1)
                    
                    if user.name != nil {
                        Text(user.email)
                            .font(.system(size: 13, weight: .regular, design: .default))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            } else {
                Text("Not signed in")
                    .font(.system(size: 16, weight: .medium, design: .default))
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var logoutIconButton: some View {
        Button(action: logout) {
            Image(systemName: "rectangle.portrait.and.arrow.right")
                .font(.system(size: 16, weight: .medium, design: .default))
                .foregroundStyle(.red)
                .frame(width: 38, height: 38)
                .background(Color.red.opacity(0.15))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(state.auth.isLoading)
        .accessibilityLabel("Sign Out")
    }
    
    private var settingsIconButton: some View {
        Button(action: openAccountSettings) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 16, weight: .medium, design: .default))
                .foregroundStyle(Color.accentColor)
                .frame(width: 38, height: 38)
                .background(Color.accentColor.opacity(0.15))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Account Settings")
    }
    
    private var defaultAvatar: some View {
        Image(systemName: "person.circle.fill")
            .resizable()
            .foregroundColor(.blue)
    }
    
    private func logout() {
_Concurrency.Task {
            await interactor.logout()
            isPresented = false
        }
    }
    
    private func openAccountSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

// MARK: - Preview

#Preview {
    SideNavigationView(isPresented: .constant(true), onSelectRoute: { _ in })
        .environment(\.injected, .previewAuthenticated)
}
