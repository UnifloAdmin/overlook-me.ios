//
//  ContentView.swift
//  overlook me
//
//  Created by Naresh Chandra on 1/8/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.injected) private var container: DIContainer
    @State private var routingState: Routing = .init()
    
    private var state: AppState { container.appState.state }
    private var interactor: ItemsInteractor { container.interactors.itemsInteractor }
    
    var body: some View {
        NavigationSplitView {
            content
                .navigationTitle("Items")
        } detail: {
            if let selectedItem = routingState.selectedItem {
                ItemDetailView(item: selectedItem)
            } else {
                Text("Select an item")
            }
        }
        .task {
            await interactor.loadItems()
        }
    }
    
    @ViewBuilder
    private var content: some View {
        if state.items.isLoading {
            ProgressView("Loading...")
        } else if let error = state.items.error {
            errorView(error)
        } else if state.items.items.isEmpty {
            emptyStateView
        } else {
            itemsList
        }
    }
    
    private var itemsList: some View {
        List {
            ForEach(state.items.items) { item in
                NavigationLink {
                    ItemDetailView(item: item)
                } label: {
                    ItemRow(item: item)
                }
            }
            .onDelete(perform: deleteItems)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
            ToolbarItem {
                Button(action: addItem) {
                    Label("Add Item", systemImage: "plus")
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Items Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Tap the + button to create your first item")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .toolbar {
            ToolbarItem {
                Button(action: addItem) {
                    Label("Add Item", systemImage: "plus")
                }
            }
        }
    }
    
    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text("Error")
                .font(.headline)
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundColor(.secondary)
            Button("Retry") {
                Task {
                    await interactor.loadItems()
                }
            }
        }
        .padding()
    }

    private func addItem() {
        Task {
            await interactor.createItem(timestamp: Date())
        }
    }

    private func deleteItems(offsets: IndexSet) {
        Task {
            for index in offsets {
                let item = state.items.items[index]
                await interactor.deleteItem(item)
            }
        }
    }
}

// MARK: - Routing

extension ContentView {
    struct Routing {
        var selectedItem: Item?
    }
}

// MARK: - Subviews

private struct ItemRow: View {
    let item: Item
    
    var body: some View {
        HStack {
            Image(systemName: "circle.fill")
                .font(.caption)
                .foregroundColor(.blue)
            Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
        }
    }
}

private struct ItemDetailView: View {
    let item: Item
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar")
                .font(.largeTitle)
                .foregroundColor(.blue)
            
            Text("Item Details")
                .font(.title)
            
            Text(item.timestamp, format: Date.FormatStyle(date: .long, time: .standard))
                .font(.headline)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Details")
    }
}

#Preview {
    ContentView()
        .environment(\.injected, .preview)
}

// MARK: - Preview Helpers

extension DIContainer {
    static var preview: Self {
        let appState = Store<AppState>(AppState())
        return DIContainer(appState: appState, interactors: .stub)
    }
}
