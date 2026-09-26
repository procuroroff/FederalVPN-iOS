import Foundation

/// Профиль пользователя в системе
public struct UserProfile: Codable, Equatable {
    public let username: String
    public let accountStatus: String
    public let daysLeft: Int
    public let subscriptionExpiration: Date?
    public let configurationEndpoint: String?
    
    public init(
        username: String,
        accountStatus: String,
        daysLeft: Int,
        subscriptionExpiration: Date? = nil,
        configurationEndpoint: String? = nil
    ) {
        self.username = username
        self.accountStatus = accountStatus
        self.daysLeft = daysLeft
        self.subscriptionExpiration = subscriptionExpiration
        self.configurationEndpoint = configurationEndpoint
    }

    public var isActive: Bool {
        return accountStatus.uppercased() == "ACTIVE" && daysLeft > 0
    }
}
