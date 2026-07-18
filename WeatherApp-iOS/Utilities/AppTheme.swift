import SwiftUI

/// The app's user-selectable appearance: follow the system, or force
/// light/dark. Persisted via `@AppStorage(AppTheme.storageKey)`.
enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let storageKey = "appTheme"
    static let `default`: AppTheme = .system

    var id: String { rawValue }

    /// `nil` tells `.preferredColorScheme` to defer to the system setting.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var titleKey: LocalizedStringKey {
        switch self {
        case .system: return "Sistema"
        case .light: return "Claro"
        case .dark: return "Escuro"
        }
    }

    var symbolName: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}
