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
    
    public init(provider: NEPacketTunnelProvider) {
        self.provider = provider
        super.init()
    }
    
    // MARK: - Жизненный цикл
    
    public func start(with config: ConnectionConfig) async throws {
        let base = Self.workBaseURL()
        let working = base.appendingPathComponent("Working")
        let temp = base.appendingPathComponent("Temp")
        try? FileManager.default.createDirectory(at: working, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        
        let options = LibboxSetupOptions()
        options.basePath = base.path
        options.workingPath = working.path
        options.tempPath = temp.path
        options.logMaxLines = 1000
        
        var setupError: NSError?
        LibboxSetup(options, &setupError)
        if let setupError = setupError {
            AppLogger.shared.error("[TunnelController] LibboxSetup failed: \(setupError.localizedDescription)")
            throw setupError
        }
        AppLogger.shared.info("[TunnelController] LibboxSetup ok")
        
        LibboxSetMemoryLimit(true)
        
        var cmdError: NSError?
        guard let server = LibboxNewCommandServer(self, self, &cmdError) else {
            let err = cmdError ?? NSError(domain: "TunnelController", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create command server"])
            AppLogger.shared.error("[TunnelController] LibboxNewCommandServer error: \(err.localizedDescription)")
            throw err
        }
        self.commandServer = server
        try server.start()
        AppLogger.shared.info("[TunnelController] CommandServer started")
        
        let configJson = config.generateSingBoxConfigJSON()
        AppLogger.shared.info("[TunnelController] Booting sing-box core for \(config.serverAddress)...")
        try server.startOrReloadService(configJson, options: LibboxOverrideOptions())
        AppLogger.shared.info("[TunnelController] sing-box core running and accepting traffic!")
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
        
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        settings.mtu = NSNumber(value: options.getMTU() > 0 ? options.getMTU() : 1500)
        
        if options.getAutoRoute() {
            if let dnsBox = try? options.getDNSServerAddress() {
                let dns = NEDNSSettings(servers: [dnsBox.value])
                dns.matchDomains = [""]
                dns.matchDomainsNoSearch = true
                settings.dnsSettings = dns
            } else {
                let dns = NEDNSSettings(servers: ["1.1.1.1", "8.8.8.8"])
                dns.matchDomains = [""]
                settings.dnsSettings = dns
            }
            
            let v4 = collectPrefixes(options.getInet4Address())
            if !v4.isEmpty {
                let ipv4 = NEIPv4Settings(addresses: v4.map(\.address), subnetMasks: v4.map(\.mask))
                let routes = collectPrefixes(options.getInet4RouteAddress())
                ipv4.includedRoutes = routes.isEmpty
                    ? [NEIPv4Route.default()]
                    : routes.map { NEIPv4Route(destinationAddress: $0.address, subnetMask: $0.mask) }
                settings.ipv4Settings = ipv4
            } else {
                let ipv4 = NEIPv4Settings(addresses: ["172.19.0.1"], subnetMasks: ["255.255.255.252"])
                ipv4.includedRoutes = [NEIPv4Route.default()]
                settings.ipv4Settings = ipv4
            }
        }
        
        self.networkSettings = settings
        try await provider.setTunnelNetworkSettings(settings)
        AppLogger.shared.info("[TunnelController] openTun: Network settings applied, MTU=\(options.getMTU())")
        
        // Hand off kernel utun descriptor to Libbox
        if let fd = provider.packetFlow.value(forKeyPath: "socket.fileDescriptor") as? Int32 {
            AppLogger.shared.info("[TunnelController] openTun: TUN fd acquired via KVC: \(fd)")
            ret0_.pointee = fd
            return
        }
        
        let fallback = LibboxGetTunnelFileDescriptor()
        guard fallback != -1 else {
            let err = NSError(domain: "TunnelController", code: 3, userInfo: [NSLocalizedDescriptionKey: "Cannot acquire utun file descriptor"])
            AppLogger.shared.error("[TunnelController] \(err.localizedDescription)")
            throw err
        }
        AppLogger.shared.info("[TunnelController] openTun: TUN fd acquired via fallback: \(fallback)")
        ret0_.pointee = fallback
    }
    
    private func collectPrefixes(_ iterator: (any LibboxRoutePrefixIteratorProtocol)?) -> [(address: String, mask: String, prefix: Int32)] {
        guard let iterator = iterator else { return [] }
        var out: [(address: String, mask: String, prefix: Int32)] = []
        while iterator.hasNext() {
            guard let p = iterator.next() else { break }
            out.append((p.address(), p.mask(), p.prefix()))
        }
        return out
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
    
    public func findConnectionOwner(_ ipProtocol: Int32, sourceAddress: String?, sourcePort: Int32, destinationAddress: String?, destinationPort: Int32) throws -> LibboxConnectionOwner {
        throw NSError(domain: "TunnelController", code: 4, userInfo: [NSLocalizedDescriptionKey: "findConnectionOwner not implemented"])
    }
    
    public func sendNotification(_ notification: LibboxNotification?) throws {}
    public func send(_ notification: LibboxNotification?) throws {}
    
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
        monitor.start(queue: .global())
        semaphore.wait()
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
    public func writeDebugMessage(_ message: String?) {
        if let msg = message, !msg.isEmpty {
            AppLogger.shared.debug("[Libbox] \(msg)")
        }
    }
}

final class InterfaceIterator: NSObject, LibboxNetworkInterfaceIteratorProtocol {
    private var iterator: Array<LibboxNetworkInterface>.Iterator
    private var peeked: LibboxNetworkInterface?
    init(_ array: [LibboxNetworkInterface]) { iterator = array.makeIterator() }
    func hasNext() -> Bool { peeked = iterator.next(); return peeked != nil }
    func next() -> LibboxNetworkInterface? { peeked }
}

@discardableResult
func runBlocking<T>(_ body: @escaping () async -> T) -> T {
    let semaphore = DispatchSemaphore(value: 0)
    var value: T?
    Task {
        value = await body()
        semaphore.signal()
    }
    semaphore.wait()
    return value!
}

func runBlockingThrowing<T>(_ body: @escaping () async throws -> T) throws -> T {
    let semaphore = DispatchSemaphore(value: 0)
    var result: Result<T, Error>!
    Task {
        do { result = .success(try await body()) } catch { result = .failure(error) }
        semaphore.signal()
    }
    semaphore.wait()
    return try result.get()
}

#endif
