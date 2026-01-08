//
//  ItemsInteractor.swift
//  overlook me
//
//  Created by Naresh Chandra on 1/8/26.
//

import Foundation
import Combine

/// Protocol defining business logic operations for Items
protocol ItemsInteractor {
    func loadItems() async
    func createItem(timestamp: Date) async
    func deleteItem(_ item: Item) async
}

// MARK: - Real Implementation

@MainActor
struct RealItemsInteractor: ItemsInteractor {
    let appState: Store<AppState>
    let repository: ItemsRepository
    
    func loadItems() async {
        appState.state.items.isLoading = true
        appState.state.items.error = nil
        
        do {
            let items = try await repository.loadItems()
            appState.state.items.items = items
            appState.state.items.isLoading = false
        } catch {
            appState.state.items.error = error
            appState.state.items.isLoading = false
        }
    }
    
    func createItem(timestamp: Date) async {
        let newItem = Item(timestamp: timestamp)
        
        do {
            try await repository.create(item: newItem)
            await loadItems()
        } catch {
            appState.state.items.error = error
        }
    }
    
    func deleteItem(_ item: Item) async {
        do {
            try await repository.delete(item: item)
            await loadItems()
        } catch {
            appState.state.items.error = error
        }
    }
}

// MARK: - Stub Implementation

struct StubItemsInteractor: ItemsInteractor {
    func loadItems() async {
        // Stub implementation
    }
    
    func createItem(timestamp: Date) async {
        // Stub implementation
    }
    
    func deleteItem(_ item: Item) async {
        // Stub implementation
    }
}
