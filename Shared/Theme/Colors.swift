import SwiftUI

public extension Color {
    // Основные цвета темы
    static let appBackground = Color(red: 0.05, green: 0.05, blue: 0.06) // Глубокий темный вулканический фон
    static let appSurface = Color(red: 0.10, green: 0.10, blue: 0.12)    // Поверхность карточек
    static let appSurfaceElevated = Color(red: 0.14, green: 0.14, blue: 0.17)
    
    // Акцентный красный
    static let appRed = Color(red: 0.88, green: 0.15, blue: 0.18)        // Яркий рубиново-красный
    static let appRedDark = Color(red: 0.60, green: 0.08, blue: 0.10)    // Темно-красный для градиентов
    static let appRedGlow = Color(red: 0.95, green: 0.20, blue: 0.22, opacity: 0.4)
    
    // Вспомогательные
    static let appGreen = Color(red: 0.15, green: 0.80, blue: 0.45)      // Для статуса CONNECTED
    static let appYellow = Color(red: 0.95, green: 0.70, blue: 0.10)     // Для статуса CONNECTING
    static let appTextSecondary = Color(white: 0.65)
    static let appTextMuted = Color(white: 0.40)
    static let appBorder = Color(white: 0.20, opacity: 0.4)
}

public extension LinearGradient {
    static let appRedGradient = LinearGradient(
        colors: [Color.appRed, Color.appRedDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let appGlassGradient = LinearGradient(
        colors: [Color.white.opacity(0.08), Color.white.opacity(0.02)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
