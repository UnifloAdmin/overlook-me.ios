//
//  Task.swift
//  overlook me
//
//  Created by Naresh Chandra
//

import Foundation

/// Domain model for Task
struct Task: Identifiable, Codable, Sendable {
    let id: String
    let userId: String
    let title: String
    
    let description: String?
    let descriptionFormat: String
    let status: TaskStatus
    let priority: TaskPriority
    
    let scheduledDate: Date?
    let scheduledTime: String?
    let dueDateTime: Date?
    
    let estimatedDurationMinutes: Int?
    let category: String?
    let project: String?
    let tags: [String]
    let color: String?
    
    let progressPercentage: Int
    let location: String?
    let latitude: Double?
    let longitude: Double?
    
    let isProModeEnabled: Bool
    let isFuture: Bool
    let isPinned: Bool
    let isArchived: Bool
    
    let importanceScore: Int
    let createdAt: Date
    let updatedAt: Date
    
    init(from dto: TaskDTO) {
        print("🏗️ [Task] Initializing from TaskDTO:")
        print("   id: \(dto.id)")
        print("   title: \(dto.title)")
        print("   status: \(dto.status?.rawValue ?? "nil")")
        print("   priority: \(dto.priority?.rawValue ?? "nil")")
        print("   description: \(dto.description ?? "nil")")
        
        self.id = dto.id
        self.userId = dto.userId
        self.title = dto.title
        self.description = dto.description
        self.descriptionFormat = dto.descriptionFormat ?? "plain"
        self.status = dto.status ?? .pending
        self.priority = dto.priority ?? .medium
        
        // Parse dates
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        self.scheduledDate = dto.scheduledDate.flatMap { isoFormatter.date(from: $0) }
        self.scheduledTime = dto.scheduledTime
        self.dueDateTime = dto.dueDateTime.flatMap { isoFormatter.date(from: $0) }
        
        self.estimatedDurationMinutes = nil
        self.category = nil
        self.project = nil
        self.tags = []
        self.color = nil
        
        self.progressPercentage = dto.progressPercentage ?? 0
        self.location = nil
        self.latitude = nil
        self.longitude = nil
        
        self.isProModeEnabled = false
        self.isFuture = false
        self.isPinned = dto.isPinned ?? false
        self.isArchived = dto.isArchived ?? false
        
        self.importanceScore = 50
        self.createdAt = dto.createdAt.flatMap { isoFormatter.date(from: $0) } ?? Date()
        self.updatedAt = dto.updatedAt.flatMap { isoFormatter.date(from: $0) } ?? Date()
        
        print("✅ [Task] Initialized with status: \(self.status.rawValue), priority: \(self.priority.rawValue)")
    }
    
    init(from dto: AutoSaveTaskResponseDTO) {
        self.id = dto.id
        self.userId = ""
        self.title = dto.title
        self.description = dto.description
        self.descriptionFormat = "plain"
        self.status = dto.status
        self.priority = dto.priority
        
        // Parse dates
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        self.scheduledDate = dto.scheduledDate.flatMap { isoFormatter.date(from: $0) }
        self.scheduledTime = dto.scheduledTime
        self.dueDateTime = dto.dueDateTime.flatMap { isoFormatter.date(from: $0) }
        
        self.estimatedDurationMinutes = nil
        self.category = dto.category
        self.project = dto.project
        self.tags = dto.tags?.split(separator: ",").map(String.init) ?? []
        self.color = dto.color
        
        self.progressPercentage = dto.progressPercentage
        self.location = dto.location
        self.latitude = dto.latitude
        self.longitude = dto.longitude
        
        self.isProModeEnabled = false
        self.isFuture = false
        self.isPinned = false
        self.isArchived = false
        
        self.importanceScore = Int(dto.importanceScore ?? 50)
        self.createdAt = isoFormatter.date(from: dto.createdAt) ?? Date()
        self.updatedAt = isoFormatter.date(from: dto.updatedAt) ?? Date()
    }
}

extension Task {
    var isOverdue: Bool {
        guard let dueDate = dueDateTime else { return false }
        return dueDate < Date() && status != .completed
    }
    
    var isDueToday: Bool {
        guard let dueDate = dueDateTime else { return false }
        return Calendar.current.isDateInToday(dueDate)
    }
    
    var isScheduledToday: Bool {
        guard let scheduled = scheduledDate else { return false }
        return Calendar.current.isDateInToday(scheduled)
    }
    
    var priorityColor: String {
        switch priority {
        case .critical: return "#FF3B30"
        case .high: return "#FF9500"
        case .medium: return "#007AFF"
        case .low: return "#8E8E93"
        }
    }
}
