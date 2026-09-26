import Foundation
import NetworkExtension
import Combine
import Network

/// Главный менеджер управления VPN-соединением на стороне основного приложения
public final class VPNManager: ObservableObject {
    public static let shared = VPNManager()
    
    @Published public private(set) var status: ConnectionStatus = .disconnected
    @Published public private(set) var activeServer: Server?
    @Published public private(set) var connectionDuration: Int = 0
    @Published public private(set) var lastError: String?
    @Published public private(set) var networkType: String = "Определение..."
    
    private var tunnelManager: NETunnelProviderManager?
    private var statusObserver: AnyCancellable?
    private var durationTimer: Timer?
    private var connectTimeoutWorkItem: DispatchWorkItem?
    
    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.federalvpn.pathmonitor")
    private let tunnelExtensionBundleId = "com.federalvpn.app.PacketTunnelExtension"
    
    private init() {
        startNetworkMonitoring()
        setupNotificationObservers()
        refreshTunnelManager()
    }
    
    deinit {
        pathMonitor.cancel()
        statusObserver?.cancel()
        durationTimer?.invalidate()
        connectTimeoutWorkItem?.cancel()
    }
    
    // MARK: - Инициализация и загрузка NETunnelProviderManager
    
    public func refreshTunnelManager(completion: ((Bool) -> Void)? = nil) {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            guard let self = self else { return }
            
            if let error = error {
                AppLogger.shared.error("[VPNManager] Failed to load tunnel managers: \(error.localizedDescription)")
                completion?(false)
                return
            }
            
            // Ищем существующий менеджер для нашего extension или создаем новый
            let manager = managers?.first(where: {
                ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == self.tunnelExtensionBundleId
            }) ?? NETunnelProviderManager()
            
            self.tunnelManager = manager
            self.updateStatusFromVPN(manager.connection.status)
            completion?(true)
        }
    }
    
    // MARK: - Управление подключением
    
    public func connect(server: Server, config: ConnectionConfig) {
        AppLogger.shared.info("[VPNManager] Requesting connection to \(server.name) (\(server.address))")
        
        self.activeServer = server
        self.status = .connecting
        self.lastError = nil
        
        // Сторожевой таймер (Watchdog): не оставлять статус CONNECTING бесконечно
        connectTimeoutWorkItem?.cancel()
        let timeoutItem = DispatchWorkItem { [weak self] in
            guard let self = self, self.status == .connecting else { return }
            AppLogger.shared.error("[VPNManager] Connection timeout reached (15s)")
            self.lastError = "Таймаут подключения к серверу"
            self.status = .error
            self.stop()
        }
        connectTimeoutWorkItem = timeoutItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 15.0, execute: timeoutItem)
        
        // Сохраняем активный конфиг для расширения
        SharedDefaults.shared.saveActiveConfig(config)
        SharedDefaults.shared.selectedServerId = server.id
        
        ensureTunnelConfigured(for: config) { [weak self] success in
            guard let self = self else { return }
            guard success, let manager = self.tunnelManager else {
                self.status = .error
                self.lastError = "Не удалось сконфигурировать системный туннель"
                return
            }
            
            do {
                let configData = try JSONEncoder().encode(config)
                let options: [String: NSObject] = ["config": configData as NSObject]
                
                try manager.connection.startVPNTunnel(options: options)
                AppLogger.shared.info("[VPNManager] startVPNTunnel called successfully")
            } catch {
                AppLogger.shared.error("[VPNManager] Failed to start tunnel: \(error.localizedDescription)")
                self.connectTimeoutWorkItem?.cancel()
                self.status = .error
                self.lastError = error.localizedDescription
            }
        }
    }
    
    public func disconnect() {
        AppLogger.shared.info("[VPNManager] Disconnecting tunnel...")
        connectTimeoutWorkItem?.cancel()
        status = .disconnecting
        stop()
    }
    
    private func stop() {
        tunnelManager?.connection.stopVPNTunnel()
        stopDurationTimer()
    }
    
    // MARK: - Подготовка системного профиля VPN
    
    private func ensureTunnelConfigured(for config: ConnectionConfig, completion: @escaping (Bool) -> Void) {
        guard let manager = tunnelManager else {
            completion(false)
            return
        }
        
        let proto = (manager.protocolConfiguration as? NETunnelProviderProtocol) ?? NETunnelProviderProtocol()
        proto.providerBundleIdentifier = tunnelExtensionBundleId
        proto.serverAddress = config.serverAddress
        
        // Разделяемый App Group для обмена данными
        proto.providerConfiguration = [
            "AppGroup": SharedDefaults.appGroupIdentifier
        ]
        
        manager.protocolConfiguration = proto
        manager.localizedDescription = "Federal VPN"
        manager.isEnabled = true
        
        // Сохранение профиля в настройки iOS (требует подтверждения пользователем при первом запуске)
        manager.saveToPreferences { [weak self] error in
            if let error = error {
                AppLogger.shared.error("[VPNManager] Failed to save tunnel preferences: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            // После сохранения перегружаем настройки для активации
            manager.loadFromPreferences { _ in
                self?.tunnelManager = manager
                completion(true)
            }
        }
    }
    
    // MARK: - Мониторинг системных статусов NEVPNStatus
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(vpnStatusDidChange(_:)),
            name: .NEVPNStatusDidChange,
            object: nil
        )
    }
    
    @objc private func vpnStatusDidChange(_ notification: Notification) {
        guard let connection = notification.object as? NEVPNConnection else { return }
        updateStatusFromVPN(connection.status)
    }
    
    private func updateStatusFromVPN(_ vpnStatus: NEVPNStatus) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            switch vpnStatus {
            case .invalid:
                self.status = .disconnected
                self.stopDurationTimer()
                
            case .disconnected:
                self.connectTimeoutWorkItem?.cancel()
                self.status = .disconnected
                self.stopDurationTimer()
                AppLogger.shared.info("[VPNManager] Status changed: DISCONNECTED")
                
            case .connecting:
                self.status = .connecting
                AppLogger.shared.info("[VPNManager] Status changed: CONNECTING")
                
            case .connected:
                self.connectTimeoutWorkItem?.cancel()
                self.status = .connected
                self.startDurationTimer()
                AppLogger.shared.info("[VPNManager] Status changed: CONNECTED")
                
            case .reasserting:
                self.status = .connecting
                AppLogger.shared.warning("[VPNManager] Tunnel is reasserting (network interface change)")
                
            case .disconnecting:
                self.status = .disconnecting
                AppLogger.shared.info("[VPNManager] Status changed: DISCONNECTING")
                
            @unknown default:
                break
            }
        }
    }
    
    // MARK: - Таймер длительности сессии
    
    private func startDurationTimer() {
        stopDurationTimer()
        connectionDuration = 0
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.connectionDuration += 1
        }
    }
    
    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
        connectionDuration = 0
    }
    
    // MARK: - Мониторинг типа сети (Wi-Fi / Cellular / No Connection)
    
    private func startNetworkMonitoring() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                if path.usesInterfaceType(.wifi) {
                    self?.networkType = "Wi-Fi"
                } else if path.usesInterfaceType(.cellular) {
                    self?.networkType = "Cellular (LTE/5G)"
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self?.networkType = "Ethernet"
                } else {
                    self?.networkType = "Нет сети"
                }
            }
        }
        pathMonitor.start(queue: monitorQueue)
    }
}
