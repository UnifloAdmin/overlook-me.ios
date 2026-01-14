//
//  TasksInteractor.swift
//  overlook me
//
//  Created by Naresh Chandra
//

import Foundation

protocol TasksInteractor {
    func loadTasks(
        status: TaskStatus?,
        priority: TaskPriority?,
        category: String?,
        project: String?,
        date: Date?,
        isPinned: Bool?,
        isArchived: Bool?,
        overdue: Bool?,
        includeCompleted: Bool
    ) async
    
    func createTask(
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
        isFuture: Bool?
    ) async
    
    func updateTask(
        taskId: String,
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
        isFuture: Bool?
    ) async
    
    func deleteTask(taskId: String) async
    func clearError()
}

enum TasksError: LocalizedError {
    case missingUser
    case taskNotFound
    
    var errorDescription: String? {
        switch self {
        case .missingUser:
            return "Unable to perform task operation without an authenticated user."
        case .taskNotFound:
            return "Task not found."
        }
    }
}

@MainActor
struct RealTasksInteractor: TasksInteractor {
    let appState: Store<AppState>
    let repository: TasksRepository
    
    func loadTasks(
        status: TaskStatus? = nil,
        priority: TaskPriority? = nil,
        category: String? = nil,
        project: String? = nil,
        date: Date? = nil,
        isPinned: Bool? = nil,
        isArchived: Bool? = nil,
        overdue: Bool? = nil,
        includeCompleted: Bool = true
    ) async {
        appState.state.tasks.isLoading = true
        appState.state.tasks.error = nil
        
        print("🔄 [TasksInteractor] Loading tasks...")
        
        guard let authUser = appState.state.auth.user else {
            print("❌ [TasksInteractor] No authenticated user found")
            appState.state.tasks.tasks = []
            appState.state.tasks.error = TasksError.missingUser
            appState.state.tasks.isLoading = false
            return
        }
        
        print("✅ [TasksInteractor] Authenticated user: \(authUser.id)")
        
        do {
            print("📡 [TasksInteractor] Fetching tasks from API...")
            let taskDTOs = try await repository.fetchTasks(
                userId: authUser.id,
                taskId: nil,
                status: status,
                priority: priority,
                category: category,
                project: project,
                date: date,
                isPinned: isPinned,
                isArchived: isArchived,
                overdue: overdue,
                includeCompleted: includeCompleted
            )
            
            print("✅ [TasksInteractor] Received \(taskDTOs.count) tasks from API")
            
            if taskDTOs.isEmpty {
                print("⚠️ [TasksInteractor] No tasks returned from API")
            } else {
                print("📋 [TasksInteractor] Task titles:")
                for (index, dto) in taskDTOs.enumerated() {
                    print("  \(index + 1). \(dto.title) (status: \(dto.status?.rawValue ?? "nil"), priority: \(dto.priority?.rawValue ?? "nil"))")
                }
            }
            
            let tasks = taskDTOs.map { Task(from: $0) }
            appState.state.tasks.tasks = tasks
            appState.state.tasks.isLoading = false
            
            print("✅ [TasksInteractor] Tasks loaded successfully into AppState")
        } catch is CancellationError {
            print("⚠️ [TasksInteractor] Request cancelled")
            appState.state.tasks.isLoading = false
        } catch let urlError as URLError where urlError.code == .cancelled {
            print("⚠️ [TasksInteractor] URL request cancelled")
            appState.state.tasks.isLoading = false
        } catch {
            print("❌ [TasksInteractor] Error loading tasks: \(error.localizedDescription)")
            appState.state.tasks.error = error
            appState.state.tasks.isLoading = false
        }
    }
    
    func createTask(
        title: String,
        description: String? = nil,
        descriptionFormat: String? = nil,
        status: TaskStatus? = nil,
        priority: TaskPriority? = nil,
        scheduledDate: Date? = nil,
        scheduledTime: String? = nil,
        dueDateTime: Date? = nil,
        estimatedDurationMinutes: Int? = nil,
        category: String? = nil,
        project: String? = nil,
        tags: String? = nil,
        color: String? = nil,
        location: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        isProModeEnabled: Bool? = nil,
        isFuture: Bool? = nil
    ) async {
        appState.state.tasks.isSaving = true
        appState.state.tasks.error = nil
        
        guard let authUser = appState.state.auth.user else {
            appState.state.tasks.error = TasksError.missingUser
            appState.state.tasks.isSaving = false
            return
        }
        
        do {
            let responseDTO = try await repository.createTask(
                userId: authUser.id,
                title: title,
                description: description,
                descriptionFormat: descriptionFormat,
                status: status,
                priority: priority,
                scheduledDate: scheduledDate,
                scheduledTime: scheduledTime,
                dueDateTime: dueDateTime,
                estimatedDurationMinutes: estimatedDurationMinutes,
                category: category,
                project: project,
                tags: tags,
                color: color,
                location: location,
                latitude: latitude,
                longitude: longitude,
                isProModeEnabled: isProModeEnabled,
                isFuture: isFuture
            )
            
            let newTask = Task(from: responseDTO)
            appState.state.tasks.tasks.append(newTask)
            appState.state.tasks.isSaving = false
            appState.state.tasks.lastCreatedTaskId = newTask.id
        } catch {
            appState.state.tasks.error = error
            appState.state.tasks.isSaving = false
        }
    }
    
    func updateTask(
        taskId: String,
        title: String? = nil,
        description: String? = nil,
        descriptionFormat: String? = nil,
        status: TaskStatus? = nil,
        priority: TaskPriority? = nil,
        scheduledDate: Date? = nil,
        scheduledTime: String? = nil,
        dueDateTime: Date? = nil,
        estimatedDurationMinutes: Int? = nil,
        category: String? = nil,
        project: String? = nil,
        tags: String? = nil,
        color: String? = nil,
        progressPercentage: Int? = nil,
        location: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        isProModeEnabled: Bool? = nil,
        isFuture: Bool? = nil
    ) async {
        appState.state.tasks.isSaving = true
        appState.state.tasks.error = nil
        
        guard let authUser = appState.state.auth.user else {
            appState.state.tasks.error = TasksError.missingUser
            appState.state.tasks.isSaving = false
            return
        }
        
        do {
            let responseDTO = try await repository.updateTask(
                taskId: taskId,
                userId: authUser.id,
                title: title,
                description: description,
                descriptionFormat: descriptionFormat,
                status: status,
                priority: priority,
                scheduledDate: scheduledDate,
                scheduledTime: scheduledTime,
                dueDateTime: dueDateTime,
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
                isFuture: isFuture
            )
            
            let updatedTask = Task(from: responseDTO)
            
            if let index = appState.state.tasks.tasks.firstIndex(where: { $0.id == taskId }) {
                appState.state.tasks.tasks[index] = updatedTask
            }
            
            appState.state.tasks.isSaving = false
        } catch {
            appState.state.tasks.error = error
            appState.state.tasks.isSaving = false
        }
    }
    
    func deleteTask(taskId: String) async {
        guard let authUser = appState.state.auth.user else {
            appState.state.tasks.error = TasksError.missingUser
            return
        }
        
        do {
            try await repository.deleteTask(taskId: taskId, userId: authUser.id)
            appState.state.tasks.tasks.removeAll { $0.id == taskId }
        } catch {
            appState.state.tasks.error = error
        }
    }
    
    func clearError() {
        appState.state.tasks.error = nil
    }
}

// MARK: - Stub Implementation

struct StubTasksInteractor: TasksInteractor {
    func loadTasks(
        status: TaskStatus?,
        priority: TaskPriority?,
        category: String?,
        project: String?,
        date: Date?,
        isPinned: Bool?,
        isArchived: Bool?,
        overdue: Bool?,
        includeCompleted: Bool
    ) async {}
    
    func createTask(
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
        isFuture: Bool?
    ) async {}
    
    func updateTask(
        taskId: String,
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
        isFuture: Bool?
    ) async {}
    
    func deleteTask(taskId: String) async {}
    func clearError() {}
}
