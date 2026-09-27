import Foundation
import Combine

/// Репозиторий серверов с автоматической предзагрузкой и автовыбором
public final class ServerRepository: ObservableObject {
    public static let shared = ServerRepository()
    
    @Published public private(set) var servers: [Server] = []
    @Published public private(set) var configs: [String: ConnectionConfig] = [:]
    @Published public var selectedServer: Server?
    @Published public private(set) var isRefreshing: Bool = false
    
    private let configRepo = ConfigurationRepository.shared
    private let latencyTester = LatencyTester.shared
    
    public init() {
        loadInitialServers()
    }
    
    private func loadInitialServers() {
        let (presetServers, presetConfigs) = configRepo.getDefaultFederalServers()
        self.configs = presetConfigs
        let cached = SharedDefaults.shared.getCachedServers()
        if !cached.isEmpty {
            self.servers = cached
            if let savedId = SharedDefaults.shared.selectedServerId,
               let match = cached.first(where: { $0.id == savedId }) {
                self.selectedServer = match
            } else {
                self.selectedServer = cached.first
            }
        } else {
            loadDefaultServers()
        }
    }
    
    public func loadDefaultServers() {
        let (presetServers, presetConfigs) = configRepo.getDefaultFederalServers()
        self.servers = presetServers
        self.configs = presetConfigs
        self.selectedServer = presetServers.first
        SharedDefaults.shared.saveCachedServers(presetServers)
        SharedDefaults.shared.selectedServerId = presetServers.first?.id
        AppLogger.shared.info("[ServerRepo] Loaded \(presetServers.count) default Federal nodes (default: \(selectedServer?.name ?? ""))")
    }
    
    public func refreshServers(from urlString: String) async {
        await MainActor.run { self.isRefreshing = true }
        
        do {
            let (newServers, newConfigs) = try await configRepo.loadConfiguration(from: urlString)
            await MainActor.run {
                if !newServers.isEmpty {
                    self.servers = newServers
                    self.configs = newConfigs
                    if self.selectedServer == nil || !newServers.contains(where: { $0.id == self.selectedServer?.id }) {
                        self.selectedServer = newServers.first
                        SharedDefaults.shared.selectedServerId = newServers.first?.id
                    }
                }
                self.isRefreshing = false
            }
            
            await pingAllServers()
        } catch {
            await MainActor.run { self.isRefreshing = false }
            AppLogger.shared.warning("[ServerRepo] Refresh error: \(error.localizedDescription)")
            if self.servers.isEmpty {
                loadDefaultServers()
            }
        }
    }
    
    public func pingAllServers() async {
        for index in servers.indices {
            let server = servers[index]
            let lat = await latencyTester.measureLatencyAsync(host: server.address, port: server.port)
            await MainActor.run {
                self.servers[index].latency = lat
                self.servers[index].available = (lat != nil)
                if self.selectedServer?.id == server.id {
                    self.selectedServer?.latency = lat
                    self.selectedServer?.available = (lat != nil)
                }
            }
        }
        SharedDefaults.shared.saveCachedServers(servers)
    }
    
    public func performAutomaticSelection() async -> Server? {
        AppLogger.shared.info("[ServerRepo] Performing automatic server selection...")
        await pingAllServers()
        
        let candidate = servers
            .filter { $0.available && ($0.latency ?? 9999) > 0 }
            .sorted { ($0.latency ?? 9999) < ($1.latency ?? 9999) }
            .first
        
        if let optimal = candidate {
            await MainActor.run {
                self.selectedServer = optimal
                SharedDefaults.shared.selectedServerId = optimal.id
            }
            AppLogger.shared.info("[ServerRepo] Auto-selected optimal server: \(optimal.name) (\(optimal.latency ?? 0)ms)")
            return optimal
        }
        
        let fallback = servers.first
        if let fallback = fallback {
            await MainActor.run {
                self.selectedServer = fallback
                SharedDefaults.shared.selectedServerId = fallback.id
            }
        }
        return fallback
    }
    
    public func selectServer(_ server: Server) {
        self.selectedServer = server
        SharedDefaults.shared.selectedServerId = server.id
    }
    
    public func configForServer(_ server: Server) -> ConnectionConfig {
        if let existing = configs[server.id] {
            return existing
        }
        // Если конфиг не найден по ID, ищем в пресетах по адресу хоста
        let (_, defaultConfigs) = configRepo.getDefaultFederalServers()
        if let match = defaultConfigs.values.first(where: { $0.serverAddress == server.address }) {
            return match
        }
        // Запасной вариант с валидным REALITY pbk
        if let defaultSw = defaultConfigs.values.first {
            return defaultSw
        }
        return ConnectionConfig(
            serverAddress: server.address,
            serverPort: server.port,
            userId: KeychainManager.shared.getString(key: .activeUserId) ?? ConfigurationRepository.defaultUserUUID,
            publicKey: "PIJ9YOUeKXNf-CY_y69wBMASbmEHyFHoc6AK_jOF2nw"
        )
    }
}
