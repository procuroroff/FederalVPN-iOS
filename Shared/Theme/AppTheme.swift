import SwiftUI

/// Цветовые темы оформления Federal VPN
public enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case crimson = "crimson"   // Федеральный Рубин (Классика)
    case magenta = "magenta"   // Кибер Маджента
    case pink    = "pink"      // Неоновый Розовый
    case cyan    = "cyan"      // Электрик Циан
    case violet  = "violet"    // Глубокий Фиолетовый
    case emerald = "emerald"   // Изумрудный Неон
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .crimson: return "Рубин"
        case .magenta: return "Маджента"
        case .pink:    return "Розовый"
        case .cyan:    return "Циан"
        case .violet:  return "Фиолетовый"
        case .emerald: return "Изумруд"
        }
    }
    
    public var primaryColor: Color {
        switch self {
        case .crimson: return Color(red: 0.88, green: 0.15, blue: 0.18)
        case .magenta: return Color(red: 0.95, green: 0.05, blue: 0.55)
        case .pink:    return Color(red: 1.0, green: 0.40, blue: 0.70)
        case .cyan:    return Color(red: 0.0, green: 0.82, blue: 1.0)
        case .violet:  return Color(red: 0.65, green: 0.25, blue: 1.0)
        case .emerald: return Color(red: 0.0, green: 0.90, blue: 0.45)
        }
    }
    
    public var darkColor: Color {
        switch self {
        case .crimson: return Color(red: 0.60, green: 0.08, blue: 0.10)
        case .magenta: return Color(red: 0.65, green: 0.0, blue: 0.35)
        case .pink:    return Color(red: 0.75, green: 0.20, blue: 0.45)
        case .cyan:    return Color(red: 0.0, green: 0.45, blue: 0.75)
        case .violet:  return Color(red: 0.40, green: 0.10, blue: 0.70)
        case .emerald: return Color(red: 0.0, green: 0.55, blue: 0.25)
        }
    }
    
    public var glowColor: Color {
        primaryColor.opacity(0.4)
    }
    
    public var gradient: LinearGradient {
        LinearGradient(
            colors: [primaryColor, darkColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// Глобальный менеджер тем оформления приложения
public final class ThemeManager: ObservableObject {
    public static let shared = ThemeManager()
    
    @Published public var currentTheme: AppTheme {
        didSet {
            SharedDefaults.shared.appTheme = currentTheme.rawValue
        }
    }
    
    private init() {
        let saved = SharedDefaults.shared.appTheme
        self.currentTheme = AppTheme(rawValue: saved) ?? .crimson
    }
    
    public func setTheme(_ theme: AppTheme) {
        withAnimation(.easeInOut(duration: 0.25)) {
            self.currentTheme = theme
        }
    }
}
