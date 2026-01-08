//
//  ItemsRepository.swift
//  overlook me
//
//  Created by Naresh Chandra on 1/8/26.
//

import Foundation
import SwiftData

/// Protocol defining the contract for Item data operations
protocol ItemsRepository {
    func loadItems() async throws -> [Item]
    func create(item: Item) async throws
    func delete(item: Item) async throws
}

// MARK: - Real Implementation

struct RealItemsRepository: ItemsRepository {
    private let modelContainer: ModelContainer
    
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }
    
    @MainActor
    func loadItems() async throws -> [Item] {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<Item>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        return try context.fetch(descriptor)
    }
    
    @MainActor
    func create(item: Item) async throws {
        let context = modelContainer.mainContext
        context.insert(item)
        try context.save()
    }
    
    @MainActor
    func delete(item: Item) async throws {
        let context = modelContainer.mainContext
        context.delete(item)
        try context.save()
    }
}

// MARK: - Stub Implementation

struct StubItemsRepository: ItemsRepository {
    func loadItems() async throws -> [Item] {
        return []
    }
    
    func create(item: Item) async throws {
        // Stub implementation
    }
    
    func delete(item: Item) async throws {
        // Stub implementation
    }
}
