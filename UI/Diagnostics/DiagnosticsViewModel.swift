import Foundation
import Combine
import UIKit

@MainActor
public final class DiagnosticsViewModel: ObservableObject {
    @Published public var connectionStatus: String = "DISCONNECTED"
    @Published public var selectedServerName: String = "Не выбран"
    @Published public var latencyString: String = "N/A"
    @Published public var networkType: String = "Определение..."
    @Published public var tunnelStatus: String = "Inactive"
    @Published public var coreStatus: String = "Idle"
    @Published public var lastError: String = "Нет"
    @Published public var logs: String = ""
    @Published public var isCopied: Bool = false
    
    private let vpnManager = VPNManager.shared
    private let serverRepo = ServerRepository.shared
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        bindObservables()
        refreshLogs()
    }
    
    private func bindObservables() {
        vpnManager.$status
            .receive(on: RunLoop.main)
            .map { $0.rawValue }
            .assign(to: \.connectionStatus, on: self)
            .store(in: &cancellables)
        
        vpnManager.$networkType
            .receive(on: RunLoop.main)
            .assign(to: \.networkType, on: self)
            .store(in: &cancellables)
        
        vpnManager.$lastError
            .receive(on: RunLoop.main)
            .map { $0 ?? "Нет ошибок" }
            .assign(to: \.lastError, on: self)
            .store(in: &cancellables)
        
        serverRepo.$selectedServer
            .receive(on: RunLoop.main)
            .sink { [weak self] server in
                guard let self = self else { return }
                self.selectedServerName = server?.name ?? "Не выбран"
                if let lat = server?.latency {
                    self.latencyString = "\(lat) ms"
                } else {
                    self.latencyString = "N/A"
                }
            }
            .store(in: &cancellables)
    }
    
    public func refreshLogs() {
        var allLogs = AppLogger.shared.exportLogs()
        if let extLog = SharedDefaults.shared.lastTunnelLog {
            allLogs += "\n[Extension] " + extLog
        }
        if let sharedLogs = try? String(contentsOfFile: "/private/var/tmp/federalvpn_tunnel.log", encoding: .utf8), !sharedLogs.isEmpty {
            allLogs += "\n=== TUNNEL CORE LOGS ===\n" + sharedLogs
        }
        logs = allLogs
        tunnelStatus = (vpnManager.status == .connected) ? "Active (TUN0)" : "Inactive"
        coreStatus = (vpnManager.status == .connected) ? "Running" : "Stopped"
    }
    
    public func copyDiagnosticsToClipboard() {
        let diagnosticReport = """
        === FEDERAL VPN DIAGNOSTICS ===
        Date: \(ISO8601DateFormatter().string(from: Date()))
        Connection Status: \(connectionStatus)
        Selected Server: \(selectedServerName)
        Latency: \(latencyString)
        Network Interface: \(networkType)
        Tunnel Virtual Interface: \(tunnelStatus)
        Core Engine Status: \(coreStatus)
        Last Error: \(lastError)
        
        === RECENT SYSTEM LOGS (SANITIZED) ===
        \(logs)
        """
        
        UIPasteboard.general.string = diagnosticReport
        isCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.isCopied = false
        }
    }
}
