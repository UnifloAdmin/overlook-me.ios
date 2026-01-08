//
//  Store.swift
//  overlook me
//
//  Created by Naresh Chandra on 1/8/26.
//

import Foundation
import Combine

/// Observable store for app state
@MainActor
final class Store<State>: ObservableObject {
    @Published var state: State
    
    init(_ state: State) {
        self.state = state
    }
    
    subscript<T>(dynamicMember keyPath: WritableKeyPath<State, T>) -> T {
        get { state[keyPath: keyPath] }
        set { state[keyPath: keyPath] = newValue }
    }
}
