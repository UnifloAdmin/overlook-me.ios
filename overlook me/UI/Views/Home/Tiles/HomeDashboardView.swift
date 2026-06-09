import SwiftUI

struct HomeDashboardView: View {
    @Environment(\.injected) private var container: DIContainer
    @StateObject private var viewModel = HomeViewModel()
    @State private var heroAppeared = false

    private var user: User? {
        container.appState.state.auth.user
    }

    /// First name only — e.g. "Naresh" from "Naresh Chandra"
    private var firstName: String {
        guard let name = user?.name, !name.isEmpty else { return "" }
        return name.components(separatedBy: " ").first ?? name
    }

    // MARK: - Design Tokens

    /// Dark wine / aubergine hero background
    private let heroColor = Color(red: 0.290, green: 0.082, blue: 0.294)  // #4A154B

    /// Glassmorphism tint for floating elements
    private let glassFill = Color.white.opacity(0.18)
    private let glassBorder = Color.white.opacity(0.3)

    @State private var showEarlyAccess = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                heroBanner

                tileSection
            }
        }
        .scrollContentBackground(.hidden)
        .background(Kalshi.bg)
        .ignoresSafeArea(edges: .top)
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) {
                heroAppeared = true
            }
        }
        .sheet(isPresented: $showEarlyAccess) {
            EarlyAccessSheet()
                .presentationSizing(.page)
                .presentationBackground(.ultraThinMaterial)
                .presentationCornerRadius(28)
        }
    }

    // ─────────────────────────────────────────────
    // MARK: - Tile Section
    // ─────────────────────────────────────────────

    private var tileSection: some View {
        LazyVStack(spacing: 14) {
            WeatherTile()
            QuitVapeTile()
            HabitsTile()
            TasksTile()
            BillsTile()
            SleepTile()
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 72)
        .background(Kalshi.bg)
    }

    // ─────────────────────────────────────────────
    // MARK: - Hero Banner
    // ─────────────────────────────────────────────

    private var heroBanner: some View {
        ZStack(alignment: .topLeading) {
            // Plain solid background
            heroColor

            // Content row
            heroContent

            // Early Access pill at bottom center
            VStack {
                Spacer()
                Button { showEarlyAccess = true } label: {
                    Text("EARLY ACCESS")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .tracking(0.6)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.18))
                                .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 0.5))
                        )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 22)
                .padding(.bottom, 14)
            }
        }
        .frame(height: 190)
        .clipped()
    }

    // ── Main content: greeting left, illustration right ──

    private var heroContent: some View {
        HStack(alignment: .bottom, spacing: 0) {
            // Left column — greeting
            VStack(alignment: .leading, spacing: 8) {
                Spacer().frame(height: 44)

                // ── Glass date pill ──
                datePill
                    .opacity(heroAppeared ? 1 : 0)
                    .offset(y: heroAppeared ? 0 : 8)

                // ── Greeting ──
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.vibeGreeting)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))

                    Text(firstName.isEmpty ? "there 👋" : firstName)
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .tracking(-0.6)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                }
                .opacity(heroAppeared ? 1 : 0)
                .offset(y: heroAppeared ? 0 : 12)

                Spacer()
            }
            .padding(.leading, 22)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Right column — logo
            Image("overlookmeLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150)
                .opacity(heroAppeared ? 1 : 0)
                .scaleEffect(heroAppeared ? 1 : 0.85)
                .offset(x: 8)
                .padding(.bottom, 4)
        }
    }

    // ── Glass-style date pill ──

    private var datePill: some View {
        HStack(spacing: 5) {
            Image(systemName: "calendar")
                .font(.system(size: 10, weight: .semibold))

            Text(viewModel.todayDateString)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.4)
                .textCase(.uppercase)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(glassFill)
                .overlay(
                    Capsule()
                        .stroke(glassBorder, lineWidth: 0.5)
                )
        )
    }

}

struct AdaptiveHomeDashboard: View {
    var body: some View {
        HomeDashboardView()
    }
}

#Preview {
    HomeDashboardView()
        .environment(\.injected, .previewAuthenticated)
}
