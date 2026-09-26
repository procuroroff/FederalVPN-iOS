import SwiftUI

public struct ConnectButton: View {
    let status: ConnectionStatus
    let action: () -> Void
    
    public init(status: ConnectionStatus, action: @escaping () -> Void) {
        self.status = status
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            ZStack {
                // Внешний пульсирующий слой при подключении/активности
                PulsingGlow(
                    isActive: status == .connecting || status == .connected,
                    color: status == .connected ? .appRed : .appYellow
                )
                .frame(width: 220, height: 220)
                
                // Внешнее металлическое/стеклянное кольцо
                Circle()
                    .stroke(
                        ringGradient,
                        lineWidth: 4
                    )
                    .frame(width: 170, height: 170)
                    .shadow(color: ringGlowColor, radius: 12)
                
                // Внутренняя поверхность кнопки
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                buttonInteriorStartColor,
                                Color(red: 0.08, green: 0.08, blue: 0.10)
                            ],
                            center: .center,
                            startRadius: 5,
                            endRadius: 80
                        )
                    )
                    .frame(width: 154, height: 154)
                
                // Иконка и текст внутри кнопки
                VStack(spacing: 8) {
                    if status == .connecting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.3)
                    } else {
                        Image(systemName: iconName)
                            .font(.system(size: 38, weight: .bold))
                            .foregroundColor(iconColor)
                    }
                    
                    Text(buttonTitle)
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(1.2)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(buttonTitle)
    }
    
    private var iconName: String {
        switch status {
        case .disconnected: return "power"
        case .connecting:   return "bolt.horizontal.fill"
        case .connected:    return "shield.checkered"
        case .disconnecting: return "power"
        case .error:        return "exclamationmark.triangle.fill"
        }
    }
    
    private var iconColor: Color {
        switch status {
        case .disconnected: return .white.opacity(0.8)
        case .connecting:   return .appYellow
        case .connected:    return .appRed
        case .disconnecting: return .appYellow
        case .error:        return .appRed
        }
    }
    
    private var buttonTitle: String {
        switch status {
        case .disconnected: return "ПОДКЛЮЧИТЬ"
        case .connecting:   return "ЗАПУСК..."
        case .connected:    return "ОТКЛЮЧИТЬ"
        case .disconnecting: return "СТОП..."
        case .error:        return "ПОВТОРИТЬ"
        }
    }
    
    private var ringGradient: LinearGradient {
        switch status {
        case .connected:
            return LinearGradient(
                colors: [.appRed, .appRedDark, .appRed],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .connecting, .disconnecting:
            return LinearGradient(
                colors: [.appYellow, .orange],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .error:
            return LinearGradient(
                colors: [.appRed, .red],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .disconnected:
            return LinearGradient(
                colors: [Color.white.opacity(0.2), Color.white.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var ringGlowColor: Color {
        switch status {
        case .connected: return Color.appRed.opacity(0.6)
        case .connecting: return Color.appYellow.opacity(0.5)
        case .error: return Color.appRed.opacity(0.7)
        case .disconnected, .disconnecting: return Color.clear
        }
    }
    
    private var buttonInteriorStartColor: Color {
        switch status {
        case .connected:
            return Color.appRedDark.opacity(0.35)
        default:
            return Color.appSurfaceElevated
        }
    }
}
