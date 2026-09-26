import Foundation

/// Профиль пользователя в системе (соответствует Android UserProfile)
public struct UserProfile: Codable, Equatable {
    public let username: String
    public let accountStatus: String
    public let daysLeft: Int
    public let expireAt: String?
    public let subscriptionEndpoint: String?
    
    public init(
        username: String,
        accountStatus: String,
        daysLeft: Int,
        expireAt: String? = nil,
        subscriptionEndpoint: String? = nil
    ) {
        self.username = username
        self.accountStatus = accountStatus
        self.daysLeft = daysLeft
        self.expireAt = expireAt
        self.subscriptionEndpoint = subscriptionEndpoint
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
        return "\(daysLeft) дн."
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
}
