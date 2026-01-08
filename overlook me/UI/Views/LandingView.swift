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
    
    var body: some View {
        ZStack {
            // Auth0 WebView - This IS the landing page
            Auth0WebView(
                onSuccess: { accessToken, idToken, refreshToken in
                    Task {
                        await interactor.completeLogin(
                            accessToken: accessToken,
                            idToken: idToken,
                            refreshToken: refreshToken
                        )
                    }
                },
                onError: { error in
                    Task {
                        await MainActor.run {
                            // Handle error - could show alert
                        }
                    }
                }
            )
            .ignoresSafeArea()
            
            // Loading overlay
            if state.auth.isLoading {
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
}

#Preview {
    LandingView()
        .environment(\.injected, .preview)
}
