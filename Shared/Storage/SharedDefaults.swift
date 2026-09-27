import Foundation

/// Разделяемые настройки между основным приложением и Network Extension через App Group
public final class SharedDefaults {
    public static let appGroupIdentifier = "group.com.federalvpn.app"
    public static let shared = SharedDefaults()
    
    private let defaults: UserDefaults
    
    private init() {
        if let groupDefaults = UserDefaults(suiteName: SharedDefaults.appGroupIdentifier) {
            self.defaults = groupDefaults
        } else {
            self.defaults = UserDefaults.standard
        }
    }
    
    private enum Keys {
        static let selectedServerId = "com.federalvpn.selectedServerId"
        static let autoConnect = "com.federalvpn.autoConnect"
        static let connectOnLaunch = "com.federalvpn.connectOnLaunch"
        static let killSwitchEnabled = "com.federalvpn.killSwitch"
        static let customDns = "com.federalvpn.customDns"
        static let isLoggingEnabled = "com.federalvpn.isLoggingEnabled"
        static let lastConnectedDate = "com.federalvpn.lastConnectedDate"
        static let activeProfile = "com.federalvpn.activeProfile"
        static let cachedServers = "com.federalvpn.cachedServers"
        static let lastActiveConfig = "com.federalvpn.lastActiveConfig"
        static let lastTunnelError = "com.federalvpn.lastTunnelError"
        static let lastTunnelLog = "com.federalvpn.lastTunnelLog"
        static let appTheme = "com.federalvpn.appTheme"
    }
    
    public var lastTunnelError: String? {
        get { defaults.string(forKey: Keys.lastTunnelError) }
        set { defaults.set(newValue, forKey: Keys.lastTunnelError) }
    }
    
    public var lastTunnelLog: String? {
        get { defaults.string(forKey: Keys.lastTunnelLog) }
        set { defaults.set(newValue, forKey: Keys.lastTunnelLog) }
    }
    
    public var selectedServerId: String? {
        get { defaults.string(forKey: Keys.selectedServerId) }
        set { defaults.set(newValue, forKey: Keys.selectedServerId) }
    }
    
    public var isAutoConnectEnabled: Bool {
        get { defaults.bool(forKey: Keys.autoConnect) }
        set { defaults.set(newValue, forKey: Keys.autoConnect) }
    }
    
    public var isConnectOnLaunchEnabled: Bool {
        get { defaults.bool(forKey: Keys.connectOnLaunch) }
        set { defaults.set(newValue, forKey: Keys.connectOnLaunch) }
    }
    
    public var isKillSwitchEnabled: Bool {
        get { defaults.bool(forKey: Keys.killSwitchEnabled) }
        set { defaults.set(newValue, forKey: Keys.killSwitchEnabled) }
    }
    
    public var customDnsServer: String {
        get { defaults.string(forKey: Keys.customDns) ?? "1.1.1.1" }
        set { defaults.set(newValue, forKey: Keys.customDns) }
    }
    
    public var isLoggingEnabled: Bool {
        get { defaults.object(forKey: Keys.isLoggingEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.isLoggingEnabled) }
    }
    
    public var lastConnectedDate: Date? {
        get { defaults.object(forKey: Keys.lastConnectedDate) as? Date }
        set { defaults.set(newValue, forKey: Keys.lastConnectedDate) }
    }
    
    public var appTheme: String {
        get { defaults.string(forKey: Keys.appTheme) ?? "crimson" }
        set { defaults.set(newValue, forKey: Keys.appTheme) }
    }
    
    // MARK: - Кеш серверов
    public func saveCachedServers(_ servers: [Server]) {
        if let data = try? JSONEncoder().encode(servers) {
            defaults.set(data, forKey: Keys.cachedServers)
        }
    }
    
    public func getCachedServers() -> [Server] {
        guard let data = defaults.data(forKey: Keys.cachedServers),
              let list = try? JSONDecoder().decode([Server].self, from: data) else {
            return []
        }
        return list
    }
    
    // MARK: - Сохранение активной конфигурации для PacketTunnel
    public func saveActiveConfig(_ config: ConnectionConfig) {
        if let data = try? JSONEncoder().encode(config) {
            defaults.set(data, forKey: Keys.lastActiveConfig)
        }
    }
    
    public func getActiveConfig() -> ConnectionConfig? {
        guard let data = defaults.data(forKey: Keys.lastActiveConfig),
              let config = try? JSONDecoder().decode(ConnectionConfig.self, from: data) else {
            return nil
        }
        return config
    }
}
