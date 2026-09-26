import Foundation

/// Протокол межпроцессного обмена (IPC) между основным приложением и PacketTunnelProvider
public enum TunnelIPCMessage: Codable {
    case ping
    case getStatus
    case getDiagnostics
    case reconnectWithConfig(ConnectionConfig)
    
    public enum Response: Codable {
        case pong
        case status(TunnelStatusReport)
        case diagnostics(String)
        case success
        case error(String)
    }
}

/// Отчёт о текущем состоянии туннеля и ядра
public struct TunnelStatusReport: Codable {
    public let isCoreRunning: Bool
    public let uptimeSeconds: Int
    public let bytesIn: UInt64
    public let bytesOut: UInt64
    public let lastError: String?
    
    public init(
        isCoreRunning: Bool,
        uptimeSeconds: Int,
        bytesIn: UInt64,
        bytesOut: UInt64,
        lastError: String? = nil
    ) {
        self.isCoreRunning = isCoreRunning
        self.uptimeSeconds = uptimeSeconds
        self.bytesIn = bytesIn
        self.bytesOut = bytesOut
        self.lastError = lastError
    }
}
