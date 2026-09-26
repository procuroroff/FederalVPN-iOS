import Foundation
import UIKit

/// Репозиторий загрузки и разбора конфигураций VLESS REALITY
public final class ConfigurationRepository: ConfigurationRepositoryProtocol {
    public static let shared = ConfigurationRepository()
    
    public static let defaultUserUUID = "7ad08a3b-53bb-4902-a0a3-6b6c4f42d019"
    
    private init() {}
    
    public func getLastWorkingConfig() -> ConnectionConfig? {
        return SharedDefaults.shared.getActiveConfig()
    }
    
    public func loadConfiguration(from urlString: String) async throws -> (servers: [Server], configs: [String: ConnectionConfig]) {
        let cleanUrl = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Если URL пустой — сразу возвращаем проверенные пресеты
        if cleanUrl.isEmpty {
            AppLogger.shared.info("[ConfigRepo] Empty URL provided, using Federal preset servers")
            return getDefaultFederalServers()
        }
        
        guard let url = URL(string: cleanUrl) else {
            AppLogger.shared.warning("[ConfigRepo] Invalid URL '\(cleanUrl)', using Federal preset servers")
            return getDefaultFederalServers()
        }
        
        AppLogger.shared.info("[ConfigRepo] Fetching subscription from \(cleanUrl)...")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("v2rayNG", forHTTPHeaderField: "User-Agent")
        
        let hwid = UIDevice.current.identifierForVendor?.uuidString.replacingOccurrences(of: "-", with "").lowercased() ?? "iosdevicehwid"
        request.setValue(hwid, forHTTPHeaderField: "x-hwid")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw APIError.serverError((response as? HTTPURLResponse)?.statusCode ?? 500)
            }
            guard let rawContent = String(data: data, encoding: .utf8), !rawContent.isEmpty else {
                throw APIError.decodingError
            }
            
            let (servers, configs) = parseSubscription(rawContent: rawContent)
            if !servers.isEmpty {
                SharedDefaults.shared.saveCachedServers(servers)
                AppLogger.shared.info("[ConfigRepo] Successfully parsed \(servers.count) servers from subscription")
                return (servers, configs)
            } else {
                AppLogger.shared.warning("[ConfigRepo] Subscription returned 0 valid nodes, falling back to presets")
                return getDefaultFederalServers()
            }
        } catch {
            AppLogger.shared.warning("[ConfigRepo] Fetch failed: \(error.localizedDescription). Falling back to Federal presets.")
            let cached = SharedDefaults.shared.getCachedServers()
            if !cached.isEmpty {
                return (cached, [:])
            }
            return getDefaultFederalServers()
        }
    }
    
    /// Парсер строк подписки (Base64 или построчный vless://)
    public func parseSubscription(rawContent: String) -> (servers: [Server], configs: [String: ConnectionConfig]) {
        var text = rawContent.trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = Data(base64Encoded: text), let decoded = String(data: data, encoding: .utf8) {
            text = decoded
        }
        
        let lines = text.components(separatedBy: .newlines)
        var servers: [Server] = []
        var configs: [String: ConnectionConfig] = [:]
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("vless://") else { continue }
            
            if let (server, config) = parseVlessURL(trimmed) {
                // Исключаем системные и ошибочные ноды
                if server.address != "0.0.0.0" && server.address != "127.0.0.1" && !server.name.contains("превышена") {
                    servers.append(server)
                    configs[server.id] = config
                }
            }
        }
        
        return (servers, configs)
    }
    
    public func parseVlessURL(_ urlString: String) -> (Server, ConnectionConfig)? {
        guard let url = URL(string: urlString),
              let host = url.host,
              let port = url.port,
              let uuid = url.user else {
            return nil
        }
        
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        
        var sni = "www.nvidia.com"
        var pbk = "PIJ9YOUeKXNf-CY_y69wBMASbmEHyFHoc6AK_jOF2nw"
        var sid = ""
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
        } else if raw.contains("Канада") || raw.contains("CA") {
            flag = "🇨🇦"; country = "Канада"
        } else if raw.contains("США") || raw.contains("US") {
            flag = "🇺🇸"; country = "США"
        }
        
        let clean = name.replacingOccurrences(of: flag, with: "").trimmingCharacters(in: .whitespaces)
        return (flag, clean.isEmpty ? country : clean, country)
    }
    
    /// Фирменные узлы Federal VPN (полное соответствие Android клиенту)
    public func getDefaultFederalServers(targetUuid: String = defaultUserUUID) -> (servers: [Server], configs: [String: ConnectionConfig]) {
        let uuid = targetUuid.isEmpty ? ConfigurationRepository.defaultUserUUID : targetUuid
        
        let rawPresets: [(id: String, name: String, country: String, flag: String, host: String, port: Int, pbk: String, sni: String, flow: String)] = [
            ("il-node", "Израиль", "Израиль", "🇮🇱", "il1.pornsite.fun", 443, "vMBpSnZ6D3NuCzambRxdCgUzEkuHVYme4pQdxlNgYQI", "www.nvidia.com", "xtls-rprx-vision"),
            ("se-node", "Швеция", "Швеция", "🇸🇪", "sw1.pornsite.fun", 443, "PIJ9YOUeKXNf-CY_y69wBMASbmEHyFHoc6AK_jOF2nw", "www.nvidia.com", "xtls-rprx-vision"),
            ("fi-node", "Финляндия", "Финляндия", "🇫🇮", "fi1.pornsite.fun", 443, "VdpFzkTakxmdOWIfM8VsqE8ZJX4Vi6rGcSnIVeEzaTU", "www.nvidia.com", "xtls-rprx-vision"),
            ("ca-node", "Канада", "Канада", "🇨🇦", "ca1.pornsite.fun", 443, "Xg-s-FtWbD-kQQz_m_j5maEkUZ-ZLAhZHjbkODK6gj4", "www.nvidia.com", "xtls-rprx-vision"),
            ("de-node", "Германия", "Германия", "🇩🇪", "de1.pornsite.fun", 8443, "tuf1EjJ-XWTkCIM2g-0vJPNQ9OlAqHYRWKvcL1UEqHQ", "www.nvidia.com", ""),
            ("us-node", "США", "США", "🇺🇸", "us1.pornsite.fun", 443, "lM6uQPdIookdcZdwYZIV51q2QGD0i0n_EZekC6RYqFk", "www.nvidia.com", "xtls-rprx-vision")
        ]
        
        var servers: [Server] = []
        var configs: [String: ConnectionConfig] = [:]
        
        for p in rawPresets {
            let server = Server(
                id: p.id,
                name: p.name,
                country: p.country,
                flag: p.flag,
                address: p.host,
                port: p.port,
                latency: nil,
                available: true
            )
            let config = ConnectionConfig(
                serverAddress: p.host,
                serverPort: p.port,
                userId: uuid,
                transport: "tcp",
                securityMode: "reality",
                serverName: p.sni,
                publicKey: p.pbk,
                shortId: "",
                fingerprint: "chrome",
                flow: p.flow
            )
            servers.append(server)
            configs[p.id] = config
        }
        
        return (servers, configs)
    }
}
