//
//  TasksRepository.swift
//  overlook me
//
//  Created by Naresh Chandra
//

import Foundation

/// Contract for task data operations.
protocol TasksRepository {
    func fetchTasks(
        userId: String,
        taskId: String?,
        status: TaskStatus?,
        priority: TaskPriority?,
        category: String?,
        project: String?,
        date: Date?,
        isPinned: Bool?,
        isArchived: Bool?,
        overdue: Bool?,
        includeCompleted: Bool
    ) async throws -> [TaskDTO]
    
    func createTask(
        userId: String,
        title: String,
        description: String?,
        descriptionFormat: String?,
        status: TaskStatus?,
        priority: TaskPriority?,
        scheduledDate: Date?,
        scheduledTime: String?,
        dueDateTime: Date?,
        estimatedDurationMinutes: Int?,
        category: String?,
        project: String?,
        tags: String?,
        color: String?,
        location: String?,
        latitude: Double?,
        longitude: Double?,
        isProModeEnabled: Bool?,
        isFuture: Bool?,
        subtasks: [SubtaskDTO]?
    ) async throws -> AutoSaveTaskResponseDTO
    
    func updateTask(
        taskId: String,
        userId: String,
        title: String?,
        description: String?,
        descriptionFormat: String?,
        status: TaskStatus?,
        priority: TaskPriority?,
        scheduledDate: Date?,
        scheduledTime: String?,
        dueDateTime: Date?,
        estimatedDurationMinutes: Int?,
        category: String?,
        project: String?,
        tags: String?,
        color: String?,
        progressPercentage: Int?,
        location: String?,
        latitude: Double?,
        longitude: Double?,
        isProModeEnabled: Bool?,
        isFuture: Bool?,
        subtasks: [SubtaskDTO]?
    ) async throws -> AutoSaveTaskResponseDTO
    
    func deleteTask(taskId: String, userId: String) async throws
    
    func createSubTask(
        taskId: String,
        userId: String,
        title: String,
        description: String?,
        status: SubTaskStatus,
        priority: SubTaskPriority,
        estimatedDurationMinutes: Int?,
        dueDateTime: Date?,
        assignedTo: String?,
        notes: String?
    ) async throws -> SubTaskResponseDTO
    
    func fetchSubTasksForTask(taskId: String) async throws -> [SubTaskDTO]
}

// MARK: - Real Implementation

struct RealTasksRepository: TasksRepository {
    private let api: TasksAPI
    private let dateFormatter: ISO8601DateFormatter
    
    init(api: TasksAPI, dateFormatter: ISO8601DateFormatter = Self.defaultDateFormatter) {
        self.api = api
        self.dateFormatter = dateFormatter
    }
    
    func fetchTasks(
        userId: String,
        taskId: String?,
        status: TaskStatus?,
        priority: TaskPriority?,
        category: String?,
        project: String?,
        date: Date?,
        isPinned: Bool?,
        isArchived: Bool?,
        overdue: Bool?,
        includeCompleted: Bool
    ) async throws -> [TaskDTO] {
        let dateString = date.map { dateFormatter.string(from: $0) }
        
        print("📡 [TasksRepository] Preparing GET request")
        print("   userId: \(userId)")
        print("   taskId: \(taskId ?? "nil")")
        print("   status: \(status?.rawValue ?? "nil")")
        print("   priority: \(priority?.rawValue ?? "nil")")
        print("   isArchived: \(isArchived?.description ?? "nil")")
        print("   includeCompleted: \(includeCompleted)")
        
        let request = GetTasksRequestDTO(
            userId: userId,
            taskId: taskId,
            status: status,
            priority: priority,
            category: category,
            project: project,
            date: dateString,
            isPinned: isPinned,
            isArchived: isArchived,
            overdue: overdue,
            includeCompleted: includeCompleted
        )
        
        let result = try await api.getTasks(request)
        print("✅ [TasksRepository] API returned \(result.count) tasks")
        return result
    }
    
    func createTask(
        userId: String,
        title: String,
        description: String?,
        descriptionFormat: String?,
        status: TaskStatus?,
        priority: TaskPriority?,
        scheduledDate: Date?,
        scheduledTime: String?,
        dueDateTime: Date?,
        estimatedDurationMinutes: Int?,
        category: String?,
        project: String?,
        tags: String?,
        color: String?,
        location: String?,
        latitude: Double?,
        longitude: Double?,
        isProModeEnabled: Bool?,
        isFuture: Bool?,
        subtasks: [SubtaskDTO]? = nil
    ) async throws -> AutoSaveTaskResponseDTO {
        print("📡 [TasksRepository] Creating task:")
        print("   title: \(title)")
        print("   dueDateTime: \(dueDateTime?.description ?? "nil")")
        
        let dueDateTimeString = dueDateTime.map { dateFormatter.string(from: $0) }
        print("   dueDateTime formatted: \(dueDateTimeString ?? "nil")")
        
        let request = AutoSaveTaskRequestDTO(
            taskId: nil,
            userId: userId,
            title: title,
            description: description,
            descriptionFormat: descriptionFormat,
            status: status,
            priority: priority,
            scheduledDate: scheduledDate.map { dateFormatter.string(from: $0) },
            scheduledTime: scheduledTime,
            dueDateTime: dueDateTimeString,
            estimatedDurationMinutes: estimatedDurationMinutes,
            category: category,
            project: project,
            tags: tags,
            color: color,
            progressPercentage: nil,
            location: location,
            latitude: latitude,
            longitude: longitude,
            isProModeEnabled: isProModeEnabled,
            isFuture: isFuture,
            lastKnownUpdatedAt: nil,
            subtasks: subtasks
        )
        
        return try await api.autoSaveTask(request)
    }
    
    func updateTask(
        taskId: String,
        userId: String,
        title: String?,
        description: String?,
        descriptionFormat: String?,
        status: TaskStatus?,
        priority: TaskPriority?,
        scheduledDate: Date?,
        scheduledTime: String?,
        dueDateTime: Date?,
        estimatedDurationMinutes: Int?,
        category: String?,
        project: String?,
        tags: String?,
        color: String?,
        progressPercentage: Int?,
        location: String?,
        latitude: Double?,
        longitude: Double?,
        isProModeEnabled: Bool?,
        isFuture: Bool?,
        subtasks: [SubtaskDTO]? = nil
    ) async throws -> AutoSaveTaskResponseDTO {
        let request = AutoSaveTaskRequestDTO(
            taskId: taskId,
            userId: userId,
            title: title,
            description: description,
            descriptionFormat: descriptionFormat,
            status: status,
            priority: priority,
            scheduledDate: scheduledDate.map { dateFormatter.string(from: $0) },
            scheduledTime: scheduledTime,
            dueDateTime: dueDateTime.map { dateFormatter.string(from: $0) },
            estimatedDurationMinutes: estimatedDurationMinutes,
            category: category,
            project: project,
            tags: tags,
            color: color,
            progressPercentage: progressPercentage,
            location: location,
            latitude: latitude,
            longitude: longitude,
            isProModeEnabled: isProModeEnabled,
            isFuture: isFuture,
            lastKnownUpdatedAt: nil,
            subtasks: subtasks
        )
        
        return try await api.updateTask(taskId: taskId, request: request)
    }
    
    func deleteTask(taskId: String, userId: String) async throws {
        _ = try await api.deleteTask(taskId: taskId, userId: userId)
    }
    
    func createSubTask(
        taskId: String,
        userId: String,
        title: String,
        description: String?,
        status: SubTaskStatus,
        priority: SubTaskPriority,
        estimatedDurationMinutes: Int?,
        dueDateTime: Date?,
        assignedTo: String?,
        notes: String?
    ) async throws -> SubTaskResponseDTO {
        print("📡 [TasksRepository] Creating subtask:")
        print("   taskId: \(taskId)")
        print("   userId: \(userId)")
        print("   title: \(title)")
        print("   status: \(status.rawValue)")
        print("   priority: \(priority.rawValue)")
        print("   dueDateTime: \(dueDateTime?.description ?? "nil")")
        
        let request = CreateSubTaskRequestDTO(
            taskId: taskId,
            userId: userId,
            title: title,
            description: description,
            status: status,
            priority: priority,
            estimatedDurationMinutes: estimatedDurationMinutes,
            dueDateTime: dueDateTime.map { dateFormatter.string(from: $0) },
            assignedTo: assignedTo,
            notes: notes
        )
        let subTasksApi = SubTasksAPI(client: api.client)
        do {
            let response = try await subTasksApi.createSubTask(request)
            print("✅ [TasksRepository] Subtask created successfully: \(response.subTask.id)")
            return response
        } catch {
            print("❌ [TasksRepository] Failed to create subtask: \(error)")
            if case APIError.httpStatus(let code, let body) = error {
                if let body = body, let bodyStr = String(data: body, encoding: .utf8) {
                    print("❌ [TasksRepository] HTTP \(code) response body: \(bodyStr)")
                }
            }
            throw error
        }
    }
    
    func fetchSubTasksForTask(taskId: String) async throws -> [SubTaskDTO] {
        let subTasksApi = SubTasksAPI(client: api.client)
        let result = try await subTasksApi.getSubTasksForTask(taskId: taskId)
        print("📡 [TasksRepository] Fetched \(result.count) subtasks for task \(taskId)")
        return result
    }
    
    private static var defaultDateFormatter: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }
}

// MARK: - Stub Implementation

struct StubTasksRepository: TasksRepository {
    func fetchTasks(
        userId: String,
        taskId: String?,
        status: TaskStatus?,
        priority: TaskPriority?,
        category: String?,
        project: String?,
        date: Date?,
        isPinned: Bool?,
        isArchived: Bool?,
        overdue: Bool?,
        includeCompleted: Bool
    ) async throws -> [TaskDTO] {
        return []
    }
    
    func createTask(
        userId: String,
        title: String,
        description: String?,
        descriptionFormat: String?,
        status: TaskStatus?,
        priority: TaskPriority?,
        scheduledDate: Date?,
        scheduledTime: String?,
        dueDateTime: Date?,
        estimatedDurationMinutes: Int?,
        category: String?,
        project: String?,
        tags: String?,
        color: String?,
        location: String?,
        latitude: Double?,
        longitude: Double?,
        isProModeEnabled: Bool?,
        isFuture: Bool?,
        subtasks: [SubtaskDTO]? = nil
    ) async throws -> AutoSaveTaskResponseDTO {
        AutoSaveTaskResponseDTO(
            id: UUID().uuidString,
            title: title,
            description: description,
            status: status ?? .pending,
            priority: priority ?? .medium,
            scheduledDate: nil,
            scheduledTime: nil,
            dueDateTime: nil,
            category: category,
            project: project,
            tags: tags,
            color: color,
            progressPercentage: 0,
            location: location,
            latitude: latitude,
            longitude: longitude,
            importanceScore: 50,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: ISO8601DateFormatter().string(from: Date()),
            isNewTask: true,
            conflictDetected: false,
            conflictMessage: nil,
            subtasks: subtasks
        )
    }
    
    func updateTask(
        taskId: String,
        userId: String,
        title: String?,
        description: String?,
        descriptionFormat: String?,
        status: TaskStatus?,
        priority: TaskPriority?,
        scheduledDate: Date?,
        scheduledTime: String?,
        dueDateTime: Date?,
        estimatedDurationMinutes: Int?,
        category: String?,
        project: String?,
        tags: String?,
        color: String?,
        progressPercentage: Int?,
        location: String?,
        latitude: Double?,
        longitude: Double?,
        isProModeEnabled: Bool?,
        isFuture: Bool?,
        subtasks: [SubtaskDTO]? = nil
    ) async throws -> AutoSaveTaskResponseDTO {
        AutoSaveTaskResponseDTO(
            id: taskId,
            title: title ?? "",
            description: description,
            status: status ?? .pending,
            priority: priority ?? .medium,
            scheduledDate: nil,
            scheduledTime: nil,
            dueDateTime: nil,
            category: category,
            project: project,
            tags: tags,
            color: color,
            progressPercentage: progressPercentage ?? 0,
            location: location,
            latitude: latitude,
            longitude: longitude,
            importanceScore: 50,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: ISO8601DateFormatter().string(from: Date()),
            isNewTask: false,
            conflictDetected: false,
            conflictMessage: nil,
            subtasks: subtasks
        )
    }
    
    func deleteTask(taskId: String, userId: String) async throws {
        // No-op for stub
    }
    
    func createSubTask(
        taskId: String,
        userId: String,
        title: String,
        description: String?,
        status: SubTaskStatus,
        priority: SubTaskPriority,
        estimatedDurationMinutes: Int?,
        dueDateTime: Date?,
        assignedTo: String?,
        notes: String?
    ) async throws -> SubTaskResponseDTO {
        SubTaskResponseDTO(
            message: "Success",
            subTask: SubTaskDTO(
                id: UUID().uuidString,
                taskId: taskId,
                userId: userId,
                title: title,
                description: description,
                status: status,
                sortOrder: 0,
                isCompleted: false,
                priority: priority,
                progressPercentage: 0,
                dueDateTime: dueDateTime.map { ISO8601DateFormatter().string(from: $0) },
                createdAt: ISO8601DateFormatter().string(from: Date()),
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )
        )
    }
    
    func fetchSubTasksForTask(taskId: String) async throws -> [SubTaskDTO] {
        return []
    }
}
