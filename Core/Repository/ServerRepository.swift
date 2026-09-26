import Foundation
import Combine

/// Репозиторий управления серверами и логикой автовыбора наилучшего узла
public final class ServerRepository: ObservableObject {
    public static let shared = ServerRepository()
    
    @Published public private(set) var servers: [Server] = []
    @Published public private(set) var configs: [String: ConnectionConfig] = [:]
    @Published public var selectedServer: Server?
    @Published public private(set) var isRefreshing: Bool = false
    
    private let configRepo: ConfigurationRepositoryProtocol
    private let latencyTester = LatencyTester.shared
    
    public init(configRepo: ConfigurationRepositoryProtocol = ConfigurationRepository.shared) {
        self.configRepo = configRepo
        loadCachedServers()
    }
    
    private func loadCachedServers() {
        let cached = SharedDefaults.shared.getCachedServers()
        if !cached.isEmpty {
            self.servers = cached
            if let savedId = SharedDefaults.shared.selectedServerId,
               let match = cached.first(where: { $0.id == savedId }) {
                self.selectedServer = match
            } else {
                self.selectedServer = cached.first
            }
        }
    }
    
    /// Обновление списка серверов из подписки
    public func refreshServers(from urlString: String) async {
        await MainActor.run { self.isRefreshing = true }
        
        do {
            let (newServers, newConfigs) = try await configRepo.loadConfiguration(from: urlString)
            await MainActor.run {
                self.servers = newServers
                self.configs = newConfigs
                if self.selectedServer == nil || !newServers.contains(where: { $0.id == self.selectedServer?.id }) {
                    self.selectedServer = newServers.first
                }
                self.isRefreshing = false
            }
            
            // Фоновый замер задержки для актуализации списка
            await pingAllServers()
        } catch {
            await MainActor.run {
                self.isRefreshing = false
            }
            AppLogger.shared.error("[ServerRepo] Refresh error: \(error.localizedDescription)")
        }
    }
    
    /// Пинг всех серверов в списке
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
    
    /// Автоматический выбор наилучшего сервера по минимальной задержке и доступности
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
        
        // Fallback к первому доступному, если пинг не удался
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
        // Запасная конфигурация по адресу и порту сервера
        return ConnectionConfig(
            serverAddress: server.address,
            serverPort: server.port,
            userId: KeychainManager.shared.getString(key: .activeUserId) ?? "USER_ID_PLACEHOLDER"
        )
    }
}
