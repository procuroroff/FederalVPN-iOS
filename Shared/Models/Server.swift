import Foundation

/// Модель сервера для подключения
public struct Server: Identifiable, Codable, Hashable {
    public let id: String
    public let name: String
    public let country: String
    public let flag: String
    public let address: String
    public let port: Int
    public var latency: Int?
    public var available: Bool
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        country: String,
        flag: String,
        address: String,
        port: Int,
        latency: Int? = nil,
        available: Bool = true
    ) {
        self.id = id
        self.name = name
        self.country = country
        self.flag = flag
        self.address = address
        self.port = port
        self.latency = latency
        self.available = available
    }
}

/// Статус доступности узла
public enum ServerHealthStatus {
    case optimal    // < 100ms
    case good       // 100 - 250ms
    case poor       // > 250ms
    case offline    // недоступен
    
    public static func evaluate(latency: Int?, available: Bool) -> ServerHealthStatus {
        guard available, let lat = latency, lat > 0 else { return .offline }
        if lat < 100 { return .optimal }
        if lat <= 250 { return .good }
        return .poor
    }
}
