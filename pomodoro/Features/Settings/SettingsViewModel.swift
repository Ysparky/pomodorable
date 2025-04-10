import SwiftUI

class SettingsViewModel: ObservableObject {
    // Referencias a los servicios compartidos
    @Published var themeService = ThemeService.shared
    @Published var colorService = ColorService.shared
    
    // Método para resetear la configuración
    func resetToDefaultSettings() {
        SettingsService.shared.resetToDefaults()
    }
}
