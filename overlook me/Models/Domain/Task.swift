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
        
        // Parse dates with multiple format support
        func parseDate(_ dateString: String?) -> Date? {
            guard let dateString = dateString else { return nil }
            print("🔍 [Task] Parsing date string: '\(dateString)'")
            
            // Try ISO8601 with fractional seconds
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            if let date = isoFormatter.date(from: dateString) {
                print("✅ [Task] Parsed with fractional seconds: \(date)")
                return date
            }
            
            // Try ISO8601 without fractional seconds
            let isoFormatterNoFractional = ISO8601DateFormatter()
            isoFormatterNoFractional.formatOptions = [.withInternetDateTime]
            
            if let date = isoFormatterNoFractional.date(from: dateString) {
                print("✅ [Task] Parsed without fractional seconds: \(date)")
                return date
            }
            
            // Handle .NET DateTime format with variable fractional seconds (up to 7 digits)
            // Normalize by truncating fractional seconds to 3 digits
            if let normalizedString = normalizeDotNetDateTime(dateString) {
                print("🔧 [Task] Normalized date string: '\(normalizedString)'")
                if let date = isoFormatter.date(from: normalizedString) {
                    print("✅ [Task] Parsed normalized date: \(date)")
                    return date
                }
            }
            
            // Last resort: try DateFormatter with custom format
            let customFormatter = DateFormatter()
            customFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSS"
            customFormatter.locale = Locale(identifier: "en_US_POSIX")
            customFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            
            if let date = customFormatter.date(from: dateString) {
                print("✅ [Task] Parsed with custom formatter: \(date)")
                return date
            }
            
            print("❌ [Task] Failed to parse date: '\(dateString)'")
            return nil
        }
        
        // Helper to normalize .NET DateTime strings
        func normalizeDotNetDateTime(_ dateString: String) -> String? {
            // Match pattern: 2026-01-15T02:33:39.3980939
            let pattern = #"^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})\.(\d+)$"#
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: dateString, range: NSRange(dateString.startIndex..., in: dateString)) else {
                return nil
            }
            
            guard let datePartRange = Range(match.range(at: 1), in: dateString),
                  let fractionRange = Range(match.range(at: 2), in: dateString) else {
                return nil
            }
            
            let datePart = String(dateString[datePartRange])
            let fraction = String(dateString[fractionRange])
            
            // Truncate or pad to 3 digits
            let normalizedFraction = fraction.count > 3 ? String(fraction.prefix(3)) : fraction.padding(toLength: 3, withPad: "0", startingAt: 0)
            
            return "\(datePart).\(normalizedFraction)Z"
        }
        
        print("🔍 [Task] DTO fields - scheduledDate: \(dto.scheduledDate ?? "nil"), dueDateTime: \(dto.dueDateTime ?? "nil")")
        
        if let scheduledStr = dto.scheduledDate {
            print("📅 [Task] Parsing scheduledDate: \(scheduledStr)")
            self.scheduledDate = parseDate(scheduledStr)
            print("   Result: \(self.scheduledDate?.description ?? "nil")")
        } else {
            self.scheduledDate = nil
        }
        
        self.scheduledTime = dto.scheduledTime
        
        if let dueStr = dto.dueDateTime {
            print("📅 [Task] Parsing dueDateTime: \(dueStr)")
            self.dueDateTime = parseDate(dueStr)
            print("   Result: \(self.dueDateTime?.description ?? "nil")")
        } else {
            print("⚠️ [Task] No dueDateTime in DTO")
            self.dueDateTime = nil
        }
        
        self.estimatedDurationMinutes = dto.estimatedDurationMinutes
        self.category = dto.category
        self.project = dto.project
        self.tags = dto.tags?.split(separator: ",").map(String.init) ?? []
        self.color = dto.color
        
        self.progressPercentage = dto.progressPercentage ?? 0
        self.location = dto.location
        self.latitude = dto.latitude
        self.longitude = dto.longitude
        
        self.isProModeEnabled = dto.isProModeEnabled ?? false
        self.isFuture = dto.isFuture ?? false
        self.isPinned = dto.isPinned ?? false
        self.isArchived = dto.isArchived ?? false
        
        self.importanceScore = dto.importanceScore ?? 50
        self.createdAt = parseDate(dto.createdAt) ?? Date()
        self.updatedAt = parseDate(dto.updatedAt) ?? Date()
        
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
        
        // Parse dates with multiple format support
        func parseDate(_ dateString: String?) -> Date? {
            guard let dateString = dateString else { return nil }
            print("🔍 [Task] Parsing date string: '\(dateString)'")
            
            // Try ISO8601 with fractional seconds
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            if let date = isoFormatter.date(from: dateString) {
                print("✅ [Task] Parsed with fractional seconds: \(date)")
                return date
            }
            
            // Try ISO8601 without fractional seconds
            let isoFormatterNoFractional = ISO8601DateFormatter()
            isoFormatterNoFractional.formatOptions = [.withInternetDateTime]
            
            if let date = isoFormatterNoFractional.date(from: dateString) {
                print("✅ [Task] Parsed without fractional seconds: \(date)")
                return date
            }
            
            // Handle .NET DateTime format with variable fractional seconds (up to 7 digits)
            // Normalize by truncating fractional seconds to 3 digits
            if let normalizedString = normalizeDotNetDateTime(dateString) {
                print("🔧 [Task] Normalized date string: '\(normalizedString)'")
                if let date = isoFormatter.date(from: normalizedString) {
                    print("✅ [Task] Parsed normalized date: \(date)")
                    return date
                }
            }
            
            // Last resort: try DateFormatter with custom format
            let customFormatter = DateFormatter()
            customFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSS"
            customFormatter.locale = Locale(identifier: "en_US_POSIX")
            customFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            
            if let date = customFormatter.date(from: dateString) {
                print("✅ [Task] Parsed with custom formatter: \(date)")
                return date
            }
            
            print("❌ [Task] Failed to parse date: '\(dateString)'")
            return nil
        }
        
        // Helper to normalize .NET DateTime strings
        func normalizeDotNetDateTime(_ dateString: String) -> String? {
            // Match pattern: 2026-01-15T02:33:39.3980939
            let pattern = #"^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})\.(\d+)$"#
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: dateString, range: NSRange(dateString.startIndex..., in: dateString)) else {
                return nil
            }
            
            guard let datePartRange = Range(match.range(at: 1), in: dateString),
                  let fractionRange = Range(match.range(at: 2), in: dateString) else {
                return nil
            }
            
            let datePart = String(dateString[datePartRange])
            let fraction = String(dateString[fractionRange])
            
            // Truncate or pad to 3 digits
            let normalizedFraction = fraction.count > 3 ? String(fraction.prefix(3)) : fraction.padding(toLength: 3, withPad: "0", startingAt: 0)
            
            return "\(datePart).\(normalizedFraction)Z"
        }
        
        self.scheduledDate = parseDate(dto.scheduledDate)
        self.scheduledTime = dto.scheduledTime
        self.dueDateTime = parseDate(dto.dueDateTime)
        
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
        self.createdAt = parseDate(dto.createdAt) ?? Date()
        self.updatedAt = parseDate(dto.updatedAt) ?? Date()
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
