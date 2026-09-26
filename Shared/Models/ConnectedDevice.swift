import Foundation

/// Модель подключенного устройства пользователя (соответствует Android ConnectedDevice)
public struct ConnectedDevice: Codable, Identifiable, Equatable {
    public var id: String { hwid }
    public let hwid: String
    public let label: String
    public let platform: String
    public let osVersion: String
    public let model: String
    public let updatedAt: String
    
    public init(
        hwid: String,
        label: String = "",
        platform: String = "",
        osVersion: String = "",
        model: String = "",
        updatedAt: String = ""
    ) {
        self.hwid = hwid
        self.label = label
        self.platform = platform
        self.osVersion = osVersion
        self.model = model
        self.updatedAt = updatedAt
    }
    
    public var displayName: String {
        if !label.trimmingCharacters(in: .whitespaces).isEmpty {
            return label
        }
        if !model.trimmingCharacters(in: .whitespaces).isEmpty {
            return model
        }
        if !platform.trimmingCharacters(in: .whitespaces).isEmpty {
            return platform
        }
        return "Устройство"
    }
    
    public var displayMeta: String {
        var parts: [String] = []
        if !platform.trimmingCharacters(in: .whitespaces).isEmpty {
            parts.append(platform)
        }
        if !osVersion.trimmingCharacters(in: .whitespaces).isEmpty {
            parts.append(osVersion)
        }
        if parts.isEmpty {
            return "Подключено к Federal VPN"
        }
        return parts.joined(separator: " • ")
    }
}
