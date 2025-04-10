import Foundation

extension String {
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
    
    func localized(with arguments: CVarArg...) -> String {
        let localizedFormat = NSLocalizedString(self, comment: "")
        return String(format: localizedFormat, arguments: arguments)
    }
    
    /// Simplificación para acceder a textos localizados con parámetros
    func localizedWithArg(_ arg: CVarArg) -> String {
        return String(format: self.localized, arg)
    }
} 