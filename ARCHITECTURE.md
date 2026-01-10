# Overlook Me - Clean Architecture

This iOS app follows **Clean Architecture** principles inspired by [nalexn/clean-architecture-swiftui](https://github.com/nalexn/clean-architecture-swiftui).

## Architecture Overview

The app is organized into three distinct layers:

### 1. **Presentation Layer** (`UI/`)
- **SwiftUI Views** that are pure functions of state
- No business logic in views
- Side effects triggered by user actions or lifecycle events
- Dependencies injected via `@Environment`

#### UI Structure:
- **Navigation/**: Global navigation components
  - `MainContainerView`: **Native iOS 26 Liquid Glass tabs** (system `TabView`)
  - `SideNavigationView`: Side menu (presented from the detached trailing tab button)
- **Views/**: Feature-specific views
- **Components/**: Reusable UI components

#### Native Liquid Glass UI (iOS 26+) — how to use it (SwiftUI)
- **Prefer system UI**: `TabView`, `Toolbar`, `NavigationStack` already render with Liquid Glass on iOS 26.
- **Native tab bar + native “drag/slide” feel**:

```swift
TabView(selection: $tab) {
  Tab("Home", systemImage: "house.fill", value: .home) { HomeView() }
  Tab("Explore", systemImage: "safari.fill", value: .explore) { ExploreView() }
  Tab(value: .searchProxy, role: .search) { Color.clear } // detached trailing pill/button
}
```

- **Detached trailing pill/button (Apple News style)**: use `Tab(role: .search, value:)`.
- **If the trailing button should open a sheet**: `onChange(of: tab)` → present, then restore previous tab.
- **Apply Liquid Glass to custom surfaces (only when needed)**:

```swift
if #available(iOS 26.0, *) {
  GlassEffectContainer {
    YourView().glassEffect(in: .capsule) // or .rect(cornerRadius:)
  }
}
```

- **Avoid**: building a fully custom tab bar if you want **native** Liquid Glass + native gestures.

### 2. **Business Logic Layer** (`Interactors/`)
- **Interactors** handle all business logic
- Receive requests from views
- Update `AppState` with results
- Never return data directly to views

### 3. **Data Access Layer** (`Repositories/`)
- **Repositories** provide async APIs for CRUD operations
- Interface with SwiftData for persistence
- Used exclusively by Interactors
- No business logic or AppState mutations

## Key Components

### AppState (`System/AppState.swift`)
The single source of truth for app state. Observable and centralized.

```swift
struct AppState {
    var system = System()
    var items = ItemsState()
}
```

### DIContainer (`System/DIContainer.swift`)
Dependency injection container that provides:
- `appState`: Centralized state store
- `interactors`: Business logic layer
- Injected into view hierarchy via `@Environment`

### Store (`System/Store.swift`)
Observable wrapper for AppState using `@Published` property wrapper.

## Data Flow

1. **User Action** → View triggers action
2. **View** → Calls Interactor method
3. **Interactor** → Executes business logic, calls Repository
4. **Repository** → Performs data operation (SwiftData)
5. **Interactor** → Updates AppState
6. **Store** → Publishes state change
7. **View** → Re-renders with new state

## Folder Structure

All modules organized into subfolders by feature (Auth/, Items/, Domain/, etc.) for scalability.

## Benefits

- ✅ **Testability**: Each layer can be tested independently
- ✅ **Separation of Concerns**: Clear boundaries between layers
- ✅ **Scalability**: Easy to add new features
- ✅ **Maintainability**: Changes isolated to specific layers
- ✅ **Dependency Injection**: Native SwiftUI injection
- ✅ **Single Source of Truth**: Centralized state management

## Testing

Each layer has stub implementations for testing:
- `StubItemsRepository`
- `StubItemsInteractor`
- Preview helpers in views

## References

- [Clean Architecture for SwiftUI](https://github.com/nalexn/clean-architecture-swiftui)
- [Separation of Concerns](https://nalexn.github.io/separation-of-concerns/)
