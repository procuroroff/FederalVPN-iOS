import Foundation

/// Состояния защищённого соединения
public enum ConnectionStatus: String, Codable {
    case disconnected = "DISCONNECTED"
    case connecting   = "CONNECTING"
    case connected    = "CONNECTED"
    case disconnecting = "DISCONNECTING"
    case error        = "ERROR"

    public var localizedTitle: String {
        switch self {
        case .disconnected: return "ОТКЛЮЧЕНО"
        case .connecting:   return "ПОДКЛЮЧЕНИЕ..."
        case .connected:    return "ПОДКЛЮЧЕНО"
        case .disconnecting: return "ОТКЛЮЧЕНИЕ..."
        case .error:        return "ОШИБКА"
        }
    }
}
