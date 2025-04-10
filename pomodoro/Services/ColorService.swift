import SwiftUI

struct TimerColors: Codable {
    var workColor: Color
    var breakColor: Color
    
    // Default colors
    static let `default` = TimerColors(
        workColor: .red,
        breakColor: .green
    )
    
    // For encoding/decoding
    enum CodingKeys: String, CodingKey {
        case workColorHex
        case breakColorHex
    }
    
    init(workColor: Color, breakColor: Color) {
        self.workColor = workColor
        self.breakColor = breakColor
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let workHex = try container.decode(String.self, forKey: .workColorHex)
        let breakHex = try container.decode(String.self, forKey: .breakColorHex)
        
        self.workColor = Color(hex: workHex) ?? .red
        self.breakColor = Color(hex: breakHex) ?? .green
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(workColor.toHex(), forKey: .workColorHex)
        try container.encode(breakColor.toHex(), forKey: .breakColorHex)
    }
}

class ColorService: ObservableObject {
    static let shared = ColorService()
    
    @AppStorage("timerColors") private var colorsData: Data = try! JSONEncoder().encode(TimerColors.default)
    
    var colors: TimerColors {
        get {
            (try? JSONDecoder().decode(TimerColors.self, from: colorsData)) ?? TimerColors.default
        }
        set {
            colorsData = (try? JSONEncoder().encode(newValue)) ?? colorsData
        }
    }
}

// Color extensions for hex conversion
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let red = Double((rgb & 0xFF0000) >> 16) / 255.0
        let green = Double((rgb & 0x00FF00) >> 8) / 255.0
        let blue = Double(rgb & 0x0000FF) / 255.0
        
        self.init(red: red, green: green, blue: blue)
    }
    
    func toHex() -> String {
        let uic = UIColor(self)
        guard let components = uic.cgColor.components, components.count >= 3 else {
            return "#000000"
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        return String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
    }
} 