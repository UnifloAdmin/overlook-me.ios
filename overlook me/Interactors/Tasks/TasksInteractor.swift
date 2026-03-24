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
        isFuture: Bool?,
        subtasks: [Subtask]?
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
        isFuture: Bool?,
        subtasks: [Subtask]?
    ) async
    
    func deleteTask(taskId: String) async
    
    func createSubTask(
        taskId: String,
        title: String,
        description: String?,
        status: SubTaskStatus,
        priority: SubTaskPriority,
        estimatedDurationMinutes: Int?,
        dueDateTime: Date?,
        assignedTo: String?,
        notes: String?
    ) async
    
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
                print("📋 [TasksInteractor] Task details:")
                for (index, dto) in taskDTOs.enumerated() {
                    print("\n  [\(index + 1)] \(dto.title)")
                    print("     - id: \(dto.id)")
                    print("     - status: \(dto.status?.rawValue ?? "nil")")
                    print("     - priority: \(dto.priority?.rawValue ?? "nil")")
                    print("     - dueDateTime: \(dto.dueDateTime ?? "nil")")
                    print("     - scheduledDate: \(dto.scheduledDate ?? "nil")")
                    print("     - subtasks: \(dto.subtasks?.count ?? 0) items")
                    if let subs = dto.subtasks, !subs.isEmpty {
                        for (si, sub) in subs.enumerated() {
                            print("       [\(si)] text=\(sub.text), completed=\(sub.completed), order=\(sub.order)")
                        }
                    }
                }
            }
            
            var tasks = taskDTOs.map { Task(from: $0) }
            
            // Fetch subtasks separately for each task (the tasks endpoint doesn't reliably include them)
            print("🔄 [TasksInteractor] Fetching subtasks for \(tasks.count) tasks...")
            for i in tasks.indices {
                do {
                    let subTaskDTOs = try await repository.fetchSubTasksForTask(taskId: tasks[i].id)
                    if !subTaskDTOs.isEmpty {
                        tasks[i].subtasks = subTaskDTOs.map { dto in
                            Subtask(
                                text: dto.title,
                                completed: dto.isCompleted ?? false,
                                order: dto.sortOrder ?? 0
                            )
                        }.sorted { $0.order < $1.order }
                        print("✅ [TasksInteractor] Task '\(tasks[i].title)' loaded \(tasks[i].subtasks.count) subtasks")
                    }
                } catch {
                    print("⚠️ [TasksInteractor] Failed to fetch subtasks for task '\(tasks[i].title)': \(error)")
                }
            }
            
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
        isFuture: Bool? = nil,
        subtasks: [Subtask]? = nil
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
                isFuture: isFuture,
                subtasks: subtasks?.map { SubtaskDTO(text: $0.text, completed: $0.completed, order: $0.order) }
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
        isFuture: Bool? = nil,
        subtasks: [Subtask]? = nil
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
                isFuture: isFuture,
                subtasks: subtasks?.map { SubtaskDTO(text: $0.text, completed: $0.completed, order: $0.order) }
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
    
    func createSubTask(
        taskId: String,
        title: String,
        description: String?,
        status: SubTaskStatus,
        priority: SubTaskPriority,
        estimatedDurationMinutes: Int?,
        dueDateTime: Date?,
        assignedTo: String?,
        notes: String?
    ) async {
        appState.state.tasks.isSaving = true
        appState.state.tasks.error = nil
        
        guard let authUser = appState.state.auth.user else {
            print("❌ [TasksInteractor] createSubTask: No authenticated user found")
            appState.state.tasks.error = TasksError.missingUser
            appState.state.tasks.isSaving = false
            return
        }
        
        print("🔄 [TasksInteractor] Creating subtask for task \(taskId) by user \(authUser.id)")
        
        do {
            let response = try await repository.createSubTask(
                taskId: taskId,
                userId: authUser.id,
                title: title,
                description: description,
                status: status,
                priority: priority,
                estimatedDurationMinutes: estimatedDurationMinutes,
                dueDateTime: dueDateTime,
                assignedTo: assignedTo,
                notes: notes
            )
            
            print("✅ [TasksInteractor] Subtask created: id=\(response.subTask.id), title=\(response.subTask.title)")
            
            // On success, append the new subtask to our locally cached parent Task so it doesn't vanish on navigate back
            let newSubtask = Subtask(
                text: response.subTask.title,
                completed: response.subTask.isCompleted ?? false,
                order: response.subTask.sortOrder ?? 0
            )
            
            if let index = appState.state.tasks.tasks.firstIndex(where: { $0.id == taskId }) {
                appState.state.tasks.tasks[index].subtasks.append(newSubtask)
                print("✅ [TasksInteractor] Subtask appended to local task at index \(index)")
            } else {
                print("⚠️ [TasksInteractor] Could not find parent task \(taskId) in local state to append subtask")
            }
            
            appState.state.tasks.isSaving = false
        } catch {
            print("❌ [TasksInteractor] createSubTask failed: \(error)")
            print("❌ [TasksInteractor] Error type: \(type(of: error))")
            print("❌ [TasksInteractor] Error description: \(error.localizedDescription)")
            appState.state.tasks.error = error
            appState.state.tasks.isSaving = false
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
        isFuture: Bool?,
        subtasks: [Subtask]?
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
        isFuture: Bool?,
        subtasks: [Subtask]?
    ) async {}
    
    func deleteTask(taskId: String) async {}
    
    func createSubTask(
        taskId: String,
        title: String,
        description: String?,
        status: SubTaskStatus,
        priority: SubTaskPriority,
        estimatedDurationMinutes: Int?,
        dueDateTime: Date?,
        assignedTo: String?,
        notes: String?
    ) async {}
    
    func clearError() {}
}
