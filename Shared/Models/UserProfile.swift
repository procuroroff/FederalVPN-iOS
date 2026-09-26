import Foundation

/// Профиль пользователя в системе (полное соответствие Android UserProfile)
public struct UserProfile: Codable, Equatable {
    public let username: String
    public let accountStatus: String
    public let daysLeft: Int
    public let expireAt: String?
    public let subscriptionEndpoint: String?
    public let telegramLinked: Bool
    public let tgUsername: String?
    public let trafficLimitBytes: Int64
    public let trafficUsedBytes: Int64
    public let happLink: String?
    
    public init(
        username: String,
        accountStatus: String,
        daysLeft: Int,
        expireAt: String? = nil,
        subscriptionEndpoint: String? = nil,
        telegramLinked: Bool = false,
        tgUsername: String? = nil,
        trafficLimitBytes: Int64 = 0,
        trafficUsedBytes: Int64 = 0,
        happLink: String? = nil
    ) {
        self.username = username
        self.accountStatus = accountStatus
        self.daysLeft = daysLeft
        self.expireAt = expireAt
        self.subscriptionEndpoint = subscriptionEndpoint
        self.telegramLinked = telegramLinked
        self.tgUsername = tgUsername
        self.trafficLimitBytes = trafficLimitBytes
        self.trafficUsedBytes = trafficUsedBytes
        self.happLink = happLink
    }

    /// Совместимость с кодом настроек
    public var configurationEndpoint: String? {
        return subscriptionEndpoint
    }

    /// Проверка на бессрочную подписку (больше 1000 дней или -1)
    public var isInfinite: Bool {
        return daysLeft > 1000 || daysLeft == -1
    }

    public var isActive: Bool {
        return accountStatus.uppercased() == "ACTIVE" || daysLeft > 0
    }

    public var formattedDaysRemaining: String {
        if isInfinite {
            return "БЕССРОЧНО"
        }
        if daysLeft >= 0 {
            return "\(daysLeft)"
        }
        return "—"
    }

    public var formattedExpiryDate: String {
        if isInfinite {
            return "Бессрочный доступ"
        }
        if let expire = expireAt, !expire.isEmpty {
            return "Действует до \(expire.prefix(10))"
        }
        return "Активна"
    }
    
    public var formattedTraffic: String {
        let usedGb = Double(trafficUsedBytes) / (1024.0 * 1024.0 * 1024.0)
        let usedStr = String(format: "%.2f", usedGb)
        if trafficLimitBytes > 0 {
            let limitGb = Double(trafficLimitBytes) / (1024.0 * 1024.0 * 1024.0)
            let limitStr = String(format: "%.1f", limitGb)
            return "\(usedStr) / \(limitStr) ГБ"
        } else {
            return "\(usedStr) ГБ (Безлимит)"
        }
    }
}
