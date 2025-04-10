import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .system: return "system".localized
        case .light: return "light".localized
        case .dark: return "dark".localized
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

class ThemeService: ObservableObject {
    static let shared = ThemeService()
    
    @AppStorage("appTheme") private var themeString: String = AppTheme.system.rawValue
    
    var currentTheme: AppTheme {
        get {
            AppTheme(rawValue: themeString) ?? .system
        }
        set {
            themeString = newValue.rawValue
        }
    }
} 