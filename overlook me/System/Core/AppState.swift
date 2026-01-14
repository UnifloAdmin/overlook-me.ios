//
//  AppState.swift
//  overlook me
//
//  Created by Naresh Chandra on 1/8/26.
//

import Foundation
import Combine

/// The single source of truth for the app's state
struct AppState {
    var system = System()
    var auth = AuthState()
    var items = ItemsState()
    var habits = HabitsState()
    var tasks = TasksState()
}

extension AppState {
    struct System {
        var isActive: Bool = false
    }
}

extension AppState {
    struct AuthState {
        var isAuthenticated: Bool = false
        var user: User?
        var isLoading: Bool = false
        var error: Error?
    }
}

extension AppState {
    struct ItemsState {
        var items: [Item] = []
        var isLoading: Bool = false
        var error: Error?
    }
}

extension AppState {
    struct HabitsState {
        var habits: [DailyHabitDTO] = []
        var isLoading: Bool = false
        var error: Error?
        var localCompletions: [String: HabitCompletionLogDTO] = [:]
        var pendingActionHabitId: String?
        var actionError: String?
    }
}

extension AppState {
    struct TasksState {
        var tasks: [Task] = []
        var isLoading: Bool = false
        var isSaving: Bool = false
        var error: Error?
        var lastCreatedTaskId: String?
    }
}
