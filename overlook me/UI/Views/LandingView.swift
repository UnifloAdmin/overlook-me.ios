//
//  LandingView.swift
//  overlook me
//
//  Created by Naresh Chandra on 1/8/26.
//

import SwiftUI

struct LandingView: View {
    @Environment(\.injected) private var container: DIContainer
    
    private var state: AppState { container.appState.state }
    private var interactor: AuthInteractor { container.interactors.authInteractor }
    
    @State private var isPresentingAuthFlow = false
    @State private var authError: String?
    
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome to")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gray)
                        .textCase(.uppercase)
                    
                    Text("overlook me")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundColor(.black)
                        .kerning(-1)
                    
                    Text("Track your habits and stay accountable every single day.")
                        .font(.body)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 28)
                .padding(.top, 64)
                
                Spacer()
                
                Button(action: { isPresentingAuthFlow = true }) {
                    Text("Log in to continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 48)
            }
            
            if state.auth.isLoading {
                loadingOverlay
            }
        }
        .fullScreenCover(isPresented: $isPresentingAuthFlow) {
            Auth0WebView(
                onSuccess: { accessToken, idToken, refreshToken in
                    isPresentingAuthFlow = false
                    _Concurrency.Task {
                        await interactor.completeLogin(
                            accessToken: accessToken,
                            idToken: idToken,
                            refreshToken: refreshToken
                        )
                    }
                },
                onError: { error in
                    isPresentingAuthFlow = false
                    _Concurrency.Task {
                        await MainActor.run {
                            authError = error.localizedDescription
                        }
                    }
                }
            )
            .ignoresSafeArea()
        }
        .alert("Unable to sign in", isPresented: Binding(
            get: { authError != nil },
            set: { if !$0 { authError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(authError ?? "")
        }
    }
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Text("Authenticating...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
        }
    }
}

#Preview {
    LandingView()
        .environment(\.injected, .preview)
}
