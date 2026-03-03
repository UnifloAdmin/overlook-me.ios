//
//  DevicesManageView.swift
//  overlook me
//
//  Created by Naresh Chandra on 1/31/26.
//

import SwiftUI

struct DevicesManageView: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "laptopcomputer.and.iphone")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    
                    Text("Manage Devices")
                        .font(.headline)
                    
                    Text("View and manage devices connected to your account.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Devices")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        DevicesManageView()
    }
}
