import Foundation

/// Протокол репозитория конфигураций
public protocol ConfigurationRepositoryProtocol {
    func loadConfiguration(from urlString: String) async throws -> (servers: [Server], configs: [String: ConnectionConfig])
    func getLastWorkingConfig() -> ConnectionConfig?
}

/// Репозиторий загрузки и разбора конфигураций и подписок VLESS + REALITY
public final class ConfigurationRepository: ConfigurationRepositoryProtocol {
    public static let shared = ConfigurationRepository()
    
    private init() {}
    
    public func getLastWorkingConfig() -> ConnectionConfig? {
        return SharedDefaults.shared.getActiveConfig()
    }
    
    public func loadConfiguration(from urlString: String) async throws -> (servers: [Server], configs: [String: ConnectionConfig]) {
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        AppLogger.shared.info("[ConfigRepo] Fetching configuration from subscription endpoint...")
        
        do {
            let rawContent = try await APIClient.shared.fetchRawString(url: url)
            let (servers, configs) = parseSubscription(rawContent: rawContent)
            
            if !servers.isEmpty {
                SharedDefaults.shared.saveCachedServers(servers)
                AppLogger.shared.info("[ConfigRepo] Successfully parsed \(servers.count) servers from subscription")
                return (servers, configs)
            } else {
                throw APIError.decodingError
            }
        } catch {
            AppLogger.shared.warning("[ConfigRepo] Fetch failed: \(error.localizedDescription). Falling back to cached servers.")
            let cached = SharedDefaults.shared.getCachedServers()
            if !cached.isEmpty {
                return (cached, [:])
            }
            throw error
        }
    }
    
    /// Парсер строк подписки (поддерживает base64 и построчные vless:// ссылки)
    public func parseSubscription(rawContent: String) -> (servers: [Server], configs: [String: ConnectionConfig]) {
        var lines: [String] = []
        
        // Проверяем, закодирован ли весь ответ в base64
        if let decodedData = Data(base64Encoded: rawContent.trimmingCharacters(in: .whitespacesAndNewlines)),
           let decodedString = String(data: decodedData, encoding: .utf8) {
            lines = decodedString.components(separatedBy: .newlines)
        } else {
            lines = rawContent.components(separatedBy: .newlines)
        }
        
        var servers: [Server] = []
        var configs: [String: ConnectionConfig] = [:]
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("vless://") else { continue }
            
            if let (server, config) = parseVlessURL(trimmed) {
                servers.append(server)
                configs[server.id] = config
            }
        }
        
        return (servers, configs)
    }
    
    /// Парсинг VLESS REALITY URL:
    /// vless://uuid@host:port?security=reality&sni=example.com&pbk=...&sid=...&flow=xtls-rprx-vision#NodeName
    public func parseVlessURL(_ urlString: String) -> (Server, ConnectionConfig)? {
        guard let url = URL(string: urlString),
              let host = url.host,
              let port = url.port,
              let uuid = url.user else {
            return nil
        }
        
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        
        var sni = "www.apple.com"
        var pbk = "PLACEHOLDER_KEY"
        var sid = "PLACEHOLDER_SID"
        var flow = "xtls-rprx-vision"
        var security = "reality"
        var transport = "tcp"
        var fp = "chrome"
        
        for item in queryItems {
            switch item.name {
            case "sni", "serverName": sni = item.value ?? sni
            case "pbk", "publicKey": pbk = item.value ?? pbk
            case "sid", "shortId": sid = item.value ?? sid
            case "flow": flow = item.value ?? flow
            case "security": security = item.value ?? security
            case "type": transport = item.value ?? transport
            case "fp": fp = item.value ?? fp
            default: break
            }
        }
        
        // Получение имени узла из fragment (#Имя)
        let rawName = url.fragment?.removingPercentEncoding ?? host
        let (flag, cleanName, country) = extractMetadata(from: rawName)
        
        let serverId = UUID().uuidString
        
        let server = Server(
            id: serverId,
            name: cleanName,
            country: country,
            flag: flag,
            address: host,
            port: port,
            latency: nil,
            available: true
        )
        
        let config = ConnectionConfig(
            serverAddress: host,
            serverPort: port,
            userId: uuid,
            transport: transport,
            securityMode: security,
            serverName: sni,
            publicKey: pbk,
            shortId: sid,
            fingerprint: fp,
            flow: flow
        )
        
        return (server, config)
    }
    
    /// Извлечение флага и страны из имени узла
    private func extractMetadata(from raw: String) -> (flag: String, name: String, country: String) {
        var flag = "🌐"
        var country = "Общий"
        var name = raw
        
        if raw.contains("Израиль") || raw.contains("IL") {
            flag = "🇮🇱"; country = "Израиль"
        } else if raw.contains("Швеция") || raw.contains("SE") {
            flag = "🇸🇪"; country = "Швеция"
        } else if raw.contains("Германия") || raw.contains("DE") {
            flag = "🇩🇪"; country = "Германия"
        } else if raw.contains("Финляндия") || raw.contains("FI") {
            flag = "🇫🇮"; country = "Финляндия"
        } else if raw.contains("Нидерланды") || raw.contains("NL") {
            flag = "🇳🇱"; country = "Нидерланды"
        } else if raw.contains("США") || raw.contains("US") {
            flag = "🇺🇸"; country = "США"
        }
        
        // Удаляем эмодзи-флаги из названия, чтобы избежать дублирования
        let clean = name.replacingOccurrences(of: flag, with: "").trimmingCharacters(in: .whitespaces)
        return (flag, clean.isEmpty ? country : clean, country)
    }
}

/// Мок-репозиторий для автономной работы и тестирования интерфейса
public final class MockConfigurationRepository: ConfigurationRepositoryProtocol {
    public init() {}
    
    public func getLastWorkingConfig() -> ConnectionConfig? {
        return ConnectionConfig.placeholder
    }
    
    public func loadConfiguration(from urlString: String) async throws -> (servers: [Server], configs: [String: ConnectionConfig]) {
        let presetServers: [Server] = [
            Server(name: "Израиль Тель-Авив", country: "Израиль", flag: "🇮🇱", address: "il1.pornsite.fun", port: 443, latency: 45, available: true),
            Server(name: "Швеция Стокгольм", country: "Швеция", flag: "🇸🇪", address: "se1.pornsite.fun", port: 443, latency: 68, available: true),
            Server(name: "Германия Франкфурт", country: "Германия", flag: "🇩🇪", address: "de1.pornsite.fun", port: 443, latency: 52, available: true),
            Server(name: "Финляндия Хельсинки", country: "Финляндия", flag: "🇫🇮", address: "fi1.pornsite.fun", port: 443, latency: 39, available: true),
            Server(name: "Нидерланды Амстердам", country: "Нидерланды", flag: "🇳🇱", address: "nl1.pornsite.fun", port: 443, latency: 58, available: true)
        ]
        
        var configs: [String: ConnectionConfig] = [:]
        for server in presetServers {
            configs[server.id] = ConnectionConfig(
                serverAddress: server.address,
                serverPort: server.port,
                userId: "USER_ID_PLACEHOLDER"
            )
        }
        
        return (presetServers, configs)
    }
}
