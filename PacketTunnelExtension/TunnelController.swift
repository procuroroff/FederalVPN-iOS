import Foundation
import Network
import NetworkExtension

#if canImport(Libbox)
import Libbox

/// Нативный мост между NEPacketTunnelProvider и ядром sing-box (Libbox)
/// Обеспечивает полную передачу пакетов TUN, gVisor TCP/IP стек и прямое VLESS REALITY соединение
public final class TunnelController: NSObject, LibboxPlatformInterfaceProtocol, LibboxCommandServerHandlerProtocol {
    private let provider: NEPacketTunnelProvider
    private var commandServer: LibboxCommandServer?
    private var networkSettings: NEPacketTunnelNetworkSettings?
    private var pathMonitor: NWPathMonitor?
    private let monitorQueue = DispatchQueue(label: "com.federalvpn.tunnel.pathmonitor")
    private var currentConfig: ConnectionConfig?
    
    public init(provider: NEPacketTunnelProvider) {
        self.provider = provider
        super.init()
    }
    
    // MARK: - Жизненный цикл
    
    public func start(with config: ConnectionConfig) async throws {
        self.currentConfig = config
        Self.appendTrollStoreLog("TunnelController: starting core for \(config.serverAddress):\(config.serverPort)")
        
        let base = Self.workBaseURL()
        let working = base.appendingPathComponent("Working")
        let temp = base.appendingPathComponent("Temp")
        try? FileManager.default.createDirectory(at: working, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        
        let options = LibboxSetupOptions()
        options.basePath = base.path
        options.workingPath = working.path
        options.tempPath = temp.path
        options.logMaxLines = 3000
        
        var setupError: NSError?
        LibboxSetup(options, &setupError)
        if let setupError = setupError {
            let msg = "LibboxSetup failed: \(setupError.localizedDescription)"
            AppLogger.shared.error("[TunnelController] \(msg)")
            Self.recordTrollStoreError(msg)
            throw setupError
        }
        AppLogger.shared.info("[TunnelController] LibboxSetup ok")
        Self.appendTrollStoreLog("TunnelController: LibboxSetup ok")
        
        LibboxSetMemoryLimit(true)
        
        var cmdError: NSError?
        guard let server = LibboxNewCommandServer(self, self, &cmdError) else {
            let err = cmdError ?? NSError(domain: "TunnelController", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create command server"])
            let msg = "LibboxNewCommandServer error: \(err.localizedDescription)"
            AppLogger.shared.error("[TunnelController] \(msg)")
            Self.recordTrollStoreError(msg)
            throw err
        }
        self.commandServer = server
        try server.start()
        AppLogger.shared.info("[TunnelController] CommandServer started")
        Self.appendTrollStoreLog("TunnelController: CommandServer started")
        
        let configJson = config.generateSingBoxConfigJSON()
        AppLogger.shared.info("[TunnelController] Booting sing-box core for \(config.serverAddress)...")
        Self.appendTrollStoreLog("TunnelController: Booting sing-box core...")
        
        do {
            try server.startOrReloadService(configJson, options: LibboxOverrideOptions())
            AppLogger.shared.info("[TunnelController] sing-box core running and accepting traffic!")
            Self.appendTrollStoreLog("TunnelController: sing-box core running and routing traffic!")
        } catch {
            let msg = "startOrReloadService failed: \(error.localizedDescription)"
            AppLogger.shared.error("[TunnelController] \(msg)")
            Self.recordTrollStoreError(msg)
            throw error
        }
    }
    
    public func stop() async {
        do {
            try commandServer?.closeService()
        } catch {
            AppLogger.shared.warning("[TunnelController] closeService error: \(error.localizedDescription)")
        }
        if let server = commandServer {
            try? await Task.sleep(nanoseconds: 100_000_000)
            server.close()
            commandServer = nil
        }
        pathMonitor?.cancel()
        pathMonitor = nil
        networkSettings = nil
        AppLogger.shared.info("[TunnelController] sing-box core stopped")
        Self.appendTrollStoreLog("TunnelController: sing-box core stopped")
    }
    
    public func sleep() {
        commandServer?.pause()
    }
    
    public func wake() {
        commandServer?.wake()
    }
    
    private static func workBaseURL() -> URL {
        if let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedDefaults.appGroupIdentifier) {
            return group
        }
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
    }
    
    // MARK: - LibboxPlatformInterfaceProtocol
    
    public func openTun(_ options: (any LibboxTunOptionsProtocol)?, ret0_: UnsafeMutablePointer<Int32>?) throws {
        try runBlockingThrowing {
            try await self.openTunAsync(options, ret0_: ret0_)
        }
    }
    
    private func openTunAsync(_ options: (any LibboxTunOptionsProtocol)?, ret0_: UnsafeMutablePointer<Int32>?) async throws {
        guard let options = options, let ret0_ = ret0_ else {
            throw NSError(domain: "TunnelController", code: 2, userInfo: [NSLocalizedDescriptionKey: "nil openTun arguments"])
        }
        
        Self.appendTrollStoreLog("openTunAsync: configuring network settings...")
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        settings.mtu = NSNumber(value: options.getMTU() > 0 ? options.getMTU() : 1500)
        
        if options.getAutoRoute() {
            var dnsServers: [String] = []
            if let dnsBox = try? options.getDNSServerAddress(), !dnsBox.value.isEmpty {
                dnsServers = [dnsBox.value]
            }
            if dnsServers.isEmpty {
                dnsServers = ["1.1.1.1", "8.8.8.8"]
            }
            let dns = NEDNSSettings(servers: dnsServers)
            dns.matchDomains = [""]
            dns.matchDomainsNoSearch = true
            settings.dnsSettings = dns
            
            var ipv4Addresses: [String] = []
            var ipv4SubnetMasks: [String] = []
            if let v4Iterator = options.getInet4Address() {
                while v4Iterator.hasNext() {
                    if let prefix = v4Iterator.next() {
                        ipv4Addresses.append(prefix.address())
                        ipv4SubnetMasks.append(prefix.mask())
                    }
                }
            }
            if ipv4Addresses.isEmpty {
                ipv4Addresses = ["172.19.0.1"]
                ipv4SubnetMasks = ["255.255.255.252"]
            }
            
            let ipv4 = NEIPv4Settings(addresses: ipv4Addresses, subnetMasks: ipv4SubnetMasks)
            
            var routes: [NEIPv4Route] = []
            if let routeIterator = options.getInet4RouteAddress() {
                while routeIterator.hasNext() {
                    if let prefix = routeIterator.next() {
                        routes.append(NEIPv4Route(destinationAddress: prefix.address(), subnetMask: prefix.mask()))
                    }
                }
            }
            ipv4.includedRoutes = routes.isEmpty ? [NEIPv4Route.default()] : routes
            
            var excludeRoutes: [NEIPv4Route] = []
            if let excludeIterator = options.getInet4RouteExcludeAddress() {
                while excludeIterator.hasNext() {
                    if let prefix = excludeIterator.next() {
                        excludeRoutes.append(NEIPv4Route(destinationAddress: prefix.address(), subnetMask: prefix.mask()))
                    }
                }
            }
            if let config = currentConfig,
               let serverIP = resolveHostToIPv4(config.serverAddress) {
                excludeRoutes.append(NEIPv4Route(destinationAddress: serverIP, subnetMask: "255.255.255.255"))
                AppLogger.shared.info("[TunnelController] Excluded VPN server IP from tunnel route: \(serverIP)")
                Self.appendTrollStoreLog("openTunAsync: Excluded server IP from tunnel route: \(serverIP)")
            }
            ipv4.excludedRoutes = excludeRoutes
            settings.ipv4Settings = ipv4
        }
        
        self.networkSettings = settings
        try await provider.setTunnelNetworkSettings(settings)
        AppLogger.shared.info("[TunnelController] openTun: Network settings applied, MTU=\(options.getMTU())")
        Self.appendTrollStoreLog("openTunAsync: settings applied, querying TUN fd...")
        
        // Loop to acquire the utun file descriptor using LibboxGetTunnelFileDescriptor()
        for attempt in 1...10 {
            let fd = LibboxGetTunnelFileDescriptor()
            if fd != -1 {
                AppLogger.shared.info("[TunnelController] openTun: TUN fd acquired on attempt \(attempt): \(fd)")
                Self.appendTrollStoreLog("openTunAsync: TUN fd acquired: \(fd) (attempt \(attempt))")
                ret0_.pointee = fd
                return
            }
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms wait
        }
        
        // Safe fallback check on packetFlow ONLY if selector is implemented to avoid NSUnknownKeyException SIGABRT
        if provider.packetFlow.responds(to: NSSelectorFromString("socket")) {
            if let socketObj = provider.packetFlow.value(forKey: "socket") as? NSObject,
               socketObj.responds(to: NSSelectorFromString("fileDescriptor")),
               let fd = socketObj.value(forKey: "fileDescriptor") as? Int32 {
                AppLogger.shared.info("[TunnelController] openTun: TUN fd acquired via packetFlow: \(fd)")
                Self.appendTrollStoreLog("openTunAsync: TUN fd acquired via packetFlow: \(fd)")
                ret0_.pointee = fd
                return
            }
        }
        
        let err = NSError(domain: "TunnelController", code: 3, userInfo: [NSLocalizedDescriptionKey: "Cannot acquire utun file descriptor after 10 attempts"])
        AppLogger.shared.error("[TunnelController] \(err.localizedDescription)")
        Self.recordTrollStoreError(err.localizedDescription)
        throw err
    }
    
    // MARK: - Required Logging & Control Protocols
    
    public func writeLog(_ message: String?) {
        guard let message = message, !message.isEmpty else { return }
        AppLogger.shared.info("[Libbox] \(message)")
        Self.appendTrollStoreLog("[Libbox] \(message)")
    }
    
    public func writeDebugMessage(_ message: String?) {
        guard let message = message, !message.isEmpty else { return }
        AppLogger.shared.debug("[Libbox] \(message)")
    }
    
    public func usePlatformAutoDetectInterfaceControl() -> Bool { false }
    public func usePlatformAutoDetectControl() -> Bool { false }
    public func autoDetectInterfaceControl(_ fd: Int32) throws {}
    public func autoDetectControl(_ fd: Int32) throws {}
    public func useProcFS() -> Bool { false }
    public func underNetworkExtension() -> Bool { true }
    public func includeAllNetworks() -> Bool { false }
    public func localDNSTransport() -> (any LibboxLocalDNSTransportProtocol)? { nil }
    public func systemCertificates() -> (any LibboxStringIteratorProtocol)? { nil }
    public func readWIFIState() -> LibboxWIFIState? { nil }
    public func readWIFISSID() -> String? { nil }
    public func usePlatformShell() -> Bool { false }
    public func checkPlatformShell() throws {}
    public func usePlatformBridge() -> Bool { false }
    public func usePlatformAutoRedirect() -> Bool { false }
    
    public func findConnectionOwner(_ ipProtocol: Int32, sourceAddress: String?, sourcePort: Int32, destinationAddress: String?, destinationPort: Int32) throws -> LibboxConnectionOwner {
        throw NSError(domain: "TunnelController", code: 4, userInfo: [NSLocalizedDescriptionKey: "findConnectionOwner not implemented"])
    }
    
    public func sendNotification(_ notification: LibboxNotification?) throws {}
    public func send(_ notification: LibboxNotification?) throws {}
    public func cancelNotification(_ identifier: String?, typeID: Int32) throws {}
    
    public func clearDNSCache() {
        guard let networkSettings = networkSettings else { return }
        runBlocking {
            self.provider.reasserting = true
            defer { self.provider.reasserting = false }
            await self.applySettings(nil)
            await self.applySettings(networkSettings)
        }
    }
    
    private func applySettings(_ settings: NEPacketTunnelNetworkSettings?) async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            provider.setTunnelNetworkSettings(settings) { _ in cont.resume() }
        }
    }
    
    public func startDefaultInterfaceMonitor(_ listener: (any LibboxInterfaceUpdateListenerProtocol)?) throws {
        guard let listener = listener else { return }
        let monitor = NWPathMonitor()
        self.pathMonitor = monitor
        let semaphore = DispatchSemaphore(value: 0)
        monitor.pathUpdateHandler = { [weak self] path in
            self?.report(path, to: listener)
            semaphore.signal()
            monitor.pathUpdateHandler = { [weak self] path in
                self?.report(path, to: listener)
            }
        }
        monitor.start(queue: monitorQueue)
        _ = semaphore.wait(timeout: .now() + 0.5)
    }
    
    private func report(_ path: Network.NWPath, to listener: any LibboxInterfaceUpdateListenerProtocol) {
        guard path.status != .unsatisfied, let iface = path.availableInterfaces.first else {
            listener.updateDefaultInterface("", interfaceIndex: -1, isExpensive: false, isConstrained: false)
            return
        }
        listener.updateDefaultInterface(iface.name, interfaceIndex: Int32(iface.index), isExpensive: path.isExpensive, isConstrained: path.isConstrained)
    }
    
    public func closeDefaultInterfaceMonitor(_ listener: (any LibboxInterfaceUpdateListenerProtocol)?) throws {
        pathMonitor?.cancel()
        pathMonitor = nil
    }
    
    public func getInterfaces() throws -> any LibboxNetworkInterfaceIteratorProtocol {
        guard let pathMonitor = pathMonitor else { return InterfaceIterator([]) }
        var list: [LibboxNetworkInterface] = []
        for it in pathMonitor.currentPath.availableInterfaces {
            let ni = LibboxNetworkInterface()
            ni.name = it.name
            ni.index = Int32(it.index)
            switch it.type {
            case .wifi: ni.type = LibboxInterfaceTypeWIFI
            case .cellular: ni.type = LibboxInterfaceTypeCellular
            case .wiredEthernet: ni.type = LibboxInterfaceTypeEthernet
            default: ni.type = LibboxInterfaceTypeOther
            }
            list.append(ni)
        }
        return InterfaceIterator(list)
    }
    
    // MARK: - LibboxCommandServerHandlerProtocol
    
    public func getSystemProxyStatus() throws -> LibboxSystemProxyStatus { LibboxSystemProxyStatus() }
    public func serviceReload() throws {}
    public func serviceStop() throws {
        try commandServer?.closeService()
    }
    public func setSystemProxyEnabled(_ enabled: Bool) throws {}
    
    // MARK: - TrollStore Logging & IPC Helper
    
    public static func recordTrollStoreError(_ error: String) {
        SharedDefaults.shared.lastTunnelError = error
        appendTrollStoreLog("ERROR: \(error)")
        
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedDefaults.appGroupIdentifier) {
            let errorFile = groupURL.appendingPathComponent("last_error.txt")
            try? error.write(to: errorFile, atomically: true, encoding: .utf8)
        }
        try? error.write(toFile: "/private/var/tmp/federalvpn_last_error.txt", atomically: true, encoding: .utf8)
    }
    
    public static func appendTrollStoreLog(_ log: String) {
        let ts = ISO8601DateFormatter().string(from: Date())
        let line = "[\(ts)] \(log)\n"
        
        SharedDefaults.shared.lastTunnelLog = log
        
        if let data = line.data(using: .utf8) {
            if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedDefaults.appGroupIdentifier) {
                let logURL = groupURL.appendingPathComponent("tunnel.log")
                if let fileHandle = try? FileHandle(forWritingTo: logURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                } else {
                    try? data.write(to: logURL, options: .atomic)
                }
            }
            
            let path = "/private/var/tmp/federalvpn_tunnel.log"
            if let fileHandle = FileHandle(forWritingAtPath: path) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            } else {
                try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
            }
        }
    }
    
    private func resolveHostToIPv4(_ host: String) -> String? {
        let clean = host.trimmingCharacters(in: .whitespacesAndNewlines)
        var sin = sockaddr_in()
        if clean.withCString({ inet_pton(AF_INET, $0, &sin.sin_addr) }) == 1 {
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
}

// MARK: - Iterators & Concurrency Helpers

final class InterfaceIterator: NSObject, LibboxNetworkInterfaceIteratorProtocol {
    private var iterator: Array<LibboxNetworkInterface>.Iterator
    private var peeked: LibboxNetworkInterface?
    init(_ array: [LibboxNetworkInterface]) { iterator = array.makeIterator() }
    func hasNext() -> Bool { peeked = iterator.next(); return peeked != nil }
    func next() -> LibboxNetworkInterface? { peeked }
}

private final class ThreadResultBox<T> {
    var result: Result<T, Error>!
    var value: T!
}

@discardableResult
func runBlocking<T>(_ body: @escaping () async -> T) -> T {
    let semaphore = DispatchSemaphore(value: 0)
    let box = ThreadResultBox<T>()
    Task.detached(priority: .userInitiated) {
        box.value = await body()
        semaphore.signal()
    }
    semaphore.wait()
    return box.value
}

func runBlockingThrowing<T>(_ body: @escaping () async throws -> T) throws -> T {
    let semaphore = DispatchSemaphore(value: 0)
    let box = ThreadResultBox<T>()
    Task.detached(priority: .userInitiated) {
        do {
            box.result = .success(try await body())
        } catch {
            box.result = .failure(error)
        }
        semaphore.signal()
    }
    semaphore.wait()
    return try box.result.get()
}

#endif
