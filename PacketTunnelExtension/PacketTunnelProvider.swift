import Foundation
import NetworkExtension

/// Главный провайдер пакетного туннеля iOS (NEPacketTunnelProvider)
public final class PacketTunnelProvider: NEPacketTunnelProvider {
    
    #if canImport(Libbox)
    private var tunnelController: TunnelController?
    #endif
    
    private let coreAdapter = NetworkCoreAdapter.shared
    private var tunnelStartTime: Date?
    private var totalBytesIn: UInt64 = 0
    private var totalBytesOut: UInt64 = 0
    private var lastErrorMessage: String?
    private var isTunnelActive: Bool = false
    
    // MARK: - Жизненный цикл туннеля
    
    public override func startTunnel(
        options: [String : NSObject]?,
        completionHandler: @escaping (Error?) -> Void
    ) {
        logExtension(">>> startTunnel initiated")
        tunnelStartTime = Date()
        lastErrorMessage = nil
        SharedDefaults.shared.lastTunnelError = nil
        try? FileManager.default.removeItem(atPath: "/private/var/tmp/federalvpn_last_error.txt")
        
        // 1. Получение конфигурации подключения (из options или SharedDefaults)
        let config: ConnectionConfig
        if let configData = options?["config"] as? Data,
           let decoded = try? JSONDecoder().decode(ConnectionConfig.self, from: configData) {
            config = decoded
            logExtension("Config received from startup options: \(config.serverAddress):\(config.serverPort)")
        } else if let cached = SharedDefaults.shared.getActiveConfig() {
            config = cached
            logExtension("Config loaded from SharedDefaults: \(config.serverAddress):\(config.serverPort)")
        } else {
            config = ConnectionConfig.placeholder
            logExtension("No explicit config provided, using placeholder config")
        }
        
        #if canImport(Libbox)
        logExtension("Starting native Sing-box (Libbox) core engine for \(config.serverAddress)...")
        let controller = TunnelController(provider: self)
        self.tunnelController = controller
        Task {
            do {
                try await controller.start(with: config)
                self.isTunnelActive = true
                self.logExtension(">>> Sing-box Tunnel is LIVE, READY and ROUTING TRAFFIC")
                completionHandler(nil)
            } catch {
                let msg = "Sing-box core startup failed: \(error.localizedDescription)"
                self.logExtension("ERROR: \(msg)")
                self.lastErrorMessage = msg
                SharedDefaults.shared.lastTunnelError = msg
                TunnelController.recordTrollStoreError(msg)
                completionHandler(error)
            }
        }
        #else
        // Fallback-режим
        let settings = createNetworkSettings(for: config)
        logExtension("Applying fallback NEPacketTunnelNetworkSettings...")
        
        setTunnelNetworkSettings(settings) { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                let msg = "Failed to apply tunnel network settings: \(error.localizedDescription)"
                self.logExtension("ERROR: \(msg)")
                self.lastErrorMessage = msg
                SharedDefaults.shared.lastTunnelError = msg
                completionHandler(error)
                return
            }
            
            self.coreAdapter.start(configuration: config) { [weak self] coreError in
                guard let self = self else { return }
                
                if let coreError = coreError {
                    let msg = "Core startup failed: \(coreError.localizedDescription)"
                    self.logExtension("ERROR: \(msg)")
                    self.lastErrorMessage = msg
                    SharedDefaults.shared.lastTunnelError = msg
                    completionHandler(coreError)
                    return
                }
                
                self.isTunnelActive = true
                self.logExtension(">>> Tunnel is READY and CONNECTED")
                self.startPacketForwardingLoop()
                completionHandler(nil)
            }
        }
        #endif
    }
    
    public override func stopTunnel(
        with reason: NEProviderStopReason,
        completionHandler: @escaping () -> Void
    ) {
        logExtension("<<< stopTunnel called with reason: \(reason.rawValue)")
        isTunnelActive = false
        tunnelStartTime = nil
        
        #if canImport(Libbox)
        Task {
            await self.tunnelController?.stop()
            self.tunnelController = nil
            completionHandler()
        }
        #else
        coreAdapter.stop()
        completionHandler()
        #endif
    }
    
    public override func sleep(completionHandler: @escaping () -> Void) {
        logExtension("Device going to sleep")
        #if canImport(Libbox)
        tunnelController?.sleep()
        #endif
        completionHandler()
    }
    
    public override func wake() {
        logExtension("Device woke up")
        #if canImport(Libbox)
        tunnelController?.wake()
        #else
        if !coreAdapter.isRunning && isTunnelActive {
            if let config = SharedDefaults.shared.getActiveConfig() {
                coreAdapter.start(configuration: config) { _ in }
            }
        }
        #endif
    }
    
    // MARK: - Межпроцессное взаимодействие (App IPC)
    
    public override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        guard let message = try? JSONDecoder().decode(TunnelIPCMessage.self, from: messageData) else {
            completionHandler?(nil)
            return
        }
        
        switch message {
        case .ping:
            let resp = TunnelIPCMessage.Response.pong
            completionHandler?(try? JSONEncoder().encode(resp))
            
        case .getStatus:
            let uptime = tunnelStartTime.map { Int(Date().timeIntervalSince($0)) } ?? 0
            let report = TunnelStatusReport(
                isCoreRunning: isTunnelActive,
                uptimeSeconds: uptime,
                bytesIn: totalBytesIn,
                bytesOut: totalBytesOut,
                lastError: lastErrorMessage
            )
            let resp = TunnelIPCMessage.Response.status(report)
            completionHandler?(try? JSONEncoder().encode(resp))
            
        case .getDiagnostics:
            let logs = AppLogger.shared.exportLogs()
            let resp = TunnelIPCMessage.Response.diagnostics(logs)
            completionHandler?(try? JSONEncoder().encode(resp))
            
        case .reconnectWithConfig(let newConfig):
            logExtension("Reconnecting with new config: \(newConfig.serverAddress)")
            #if canImport(Libbox)
            Task {
                await self.tunnelController?.stop()
                do {
                    try await self.tunnelController?.start(with: newConfig)
                    let resp = TunnelIPCMessage.Response.success
                    completionHandler?(try? JSONEncoder().encode(resp))
                } catch {
                    let resp = TunnelIPCMessage.Response.error(error.localizedDescription)
                    completionHandler?(try? JSONEncoder().encode(resp))
                }
            }
            #else
            coreAdapter.stop()
            coreAdapter.start(configuration: newConfig) { [weak self] error in
                if let error = error {
                    self?.logExtension("Reconnect failed: \(error.localizedDescription)")
                    let resp = TunnelIPCMessage.Response.error(error.localizedDescription)
                    completionHandler?(try? JSONEncoder().encode(resp))
                } else {
                    self?.logExtension("Reconnect succeeded")
                    let resp = TunnelIPCMessage.Response.success
                    completionHandler?(try? JSONEncoder().encode(resp))
                }
            }
            #endif
        }
    }
    
    // MARK: - Настройка параметров туннеля (Fallback)
    
    private func createNetworkSettings(for config: ConnectionConfig) -> NEPacketTunnelNetworkSettings {
        let resolvedServerIP = resolveHostToIPv4(config.serverAddress)
        let remoteEndpointAddress = resolvedServerIP ?? "172.19.0.1"
        
        logExtension("Server address: '\(config.serverAddress)', resolved endpoint IP: '\(remoteEndpointAddress)'")
        
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: remoteEndpointAddress)
        let tunnelIP = isValidIPv4(config.tunnelIPv4) ? config.tunnelIPv4 : "172.19.0.2"
        let tunnelMask = isValidIPv4(config.tunnelSubnetMask) ? config.tunnelSubnetMask : "255.255.255.0"
        
        let ipv4Settings = NEIPv4Settings(
            addresses: [tunnelIP],
            subnetMasks: [tunnelMask]
        )
        ipv4Settings.includedRoutes = [NEIPv4Route.default()]
        
        var excludedRoutes: [NEIPv4Route] = []
        if let serverIP = resolvedServerIP, isValidIPv4(serverIP) {
            excludedRoutes.append(NEIPv4Route(destinationAddress: serverIP, subnetMask: "255.255.255.255"))
        }
        ipv4Settings.excludedRoutes = excludedRoutes
        settings.ipv4Settings = ipv4Settings
        
        let dnsServers = config.dnsServers.filter { isValidIPv4($0) }
        let finalDns = dnsServers.isEmpty ? ["1.1.1.1", "8.8.8.8"] : dnsServers
        let dnsSettings = NEDNSSettings(servers: finalDns)
        dnsSettings.matchDomains = [""]
        settings.dnsSettings = dnsSettings
        
        settings.mtu = NSNumber(value: 1500)
        return settings
    }
    
    private func isValidIPv4(_ address: String) -> Bool {
        var sin = sockaddr_in()
        return address.withCString { inet_pton(AF_INET, $0, &sin.sin_addr) } == 1
    }
    
    private func resolveHostToIPv4(_ host: String) -> String? {
        let clean = host.trimmingCharacters(in: .whitespacesAndNewlines)
        if isValidIPv4(clean) {
            return clean
        }
        
        var hints = addrinfo(
            ai_flags: AI_DEFAULT,
            ai_family: AF_INET,
            ai_socktype: SOCK_STREAM,
            ai_protocol: 0,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil
        )
        var res: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(clean, nil, &hints, &res) == 0, let first = res else {
            return nil
        }
        defer { freeaddrinfo(res) }
        
        var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let sockAddr = first.pointee.ai_addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
        var addr = sockAddr.sin_addr
        guard inet_ntop(AF_INET, &addr, &buffer, socklen_t(NI_MAXHOST)) != nil else {
            return nil
        }
        return String(cString: buffer)
    }
    
    private func logExtension(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] [PacketTunnel] \(message)"
        AppLogger.shared.info("[PacketTunnel] \(message)")
        SharedDefaults.shared.lastTunnelLog = line
    }
    
    private func startPacketForwardingLoop() {
        guard isTunnelActive else { return }
        
        packetFlow.readPackets { [weak self] (packets, protocols) in
            guard let self = self, self.isTunnelActive else { return }
            for packet in packets {
                self.totalBytesOut += UInt64(packet.count)
            }
            self.startPacketForwardingLoop()
        }
    }
}
