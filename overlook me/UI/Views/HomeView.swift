//
//  HomeView.swift
//  overlook me
//
//  Created by Naresh Chandra on 1/8/26.
//

import SwiftUI

struct HomeView: View {
    @Environment(\.injected) private var container: DIContainer
    
    private var user: User? {
        container.appState.state.auth.user
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 40) {
                Spacer()
                
                // Welcome message
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                    
                    Text("Hello World!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    if let userName = user?.name {
                        Text("Welcome, \(userName)!")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    } else if let email = user?.email {
                        Text("Welcome, \(email)!")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Logout button
                Button(action: logout) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Sign Out")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
            .navigationTitle("Home")
        }
    }
    
    private func logout() {
        Task {
            await container.interactors.authInteractor.logout()
        }
    }
}

#Preview {
    HomeView()
        .environment(\.injected, .previewAuthenticated)
}
