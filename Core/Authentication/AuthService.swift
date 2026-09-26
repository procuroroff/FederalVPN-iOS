import Foundation
import Combine

/// Сервис авторизации пользователей и управления сессиями
public final class AuthService: ObservableObject {
    public static let shared = AuthService()
    
    @Published public private(set) var isAuthenticated: Bool = false
    @Published public private(set) var currentUserProfile: UserProfile?
    @Published public private(set) var isLoading: Bool = false
    @Published public var errorMessage: String?
    
    private let keychain = KeychainManager.shared
    private let defaults = SharedDefaults.shared
    
    private init() {
        restoreSession()
    }
    
    /// Восстановление существующей сессии из Keychain
    public func restoreSession() {
        if let token = keychain.getString(key: .authToken), !token.isEmpty {
            let savedUsername = UserDefaults.standard.string(forKey: "saved_username") ?? "Пользователь"
            self.currentUserProfile = UserProfile(
                username: savedUsername,
                accountStatus: "ACTIVE",
                daysLeft: 30,
                subscriptionExpiration: Calendar.current.date(byAdding: .day, value: 30, to: Date()),
                configurationEndpoint: "https://npv.pornsite.fun/api/sub/\(token)"
            )
            self.isAuthenticated = true
        }
    }
    
    /// Вход по логину и паролю
    public func signIn(username: String, password: String) async -> Bool {
        let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanUsername.isEmpty, !cleanPassword.isEmpty else {
            await MainActor.run { self.errorMessage = "Заполните все поля" }
            return false
        }
        
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        // В реальном окружении запрос направляется на auth endpoint:
        // let body = try? JSONSerialization.data(withJSONObject: ["login": cleanUsername, "password": cleanPassword])
        // let response: AuthResponse = try await APIClient.shared.request(endpoint: "https://federal-vpn.site/api/auth/login", method: "POST", body: body)
        
        // Для автономной стабильной работы и тестирования:
        try? await Task.sleep(nanoseconds: 600_000_000) // Имитация сетевого ответа 600ms
        
        let token = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let subEndpoint = "https://npv.pornsite.fun/api/sub/\(token)"
        
        // Сохраняем токен в Keychain (БЕЗОПАСНО, не в UserDefaults)
        _ = keychain.save(key: .authToken, string: token)
        _ = keychain.save(key: .userPassword, string: cleanPassword)
        UserDefaults.standard.set(cleanUsername, forKey: "saved_username")
        
        let profile = UserProfile(
            username: cleanUsername,
            accountStatus: "ACTIVE",
            daysLeft: 30,
            subscriptionExpiration: Calendar.current.date(byAdding: .day, value: 30, to: Date()),
            configurationEndpoint: subEndpoint
        )
        
        await MainActor.run {
            self.currentUserProfile = profile
            self.isAuthenticated = true
            self.isLoading = false
        }
        
        AppLogger.shared.info("[AuthService] User '\(cleanUsername)' signed in successfully")
        
        // Автоматически обновляем список серверов
        Task {
            await ServerRepository.shared.refreshServers(from: subEndpoint)
        }
        
        return true
    }
    
    /// Выход из аккаунта и очистка Keychain
    public func signOut() {
        _ = keychain.delete(key: .authToken)
        _ = keychain.delete(key: .userPassword)
        _ = keychain.delete(key: .activeUserId)
        UserDefaults.standard.removeObject(forKey: "saved_username")
        
        currentUserProfile = nil
        isAuthenticated = false
        VPNManager.shared.disconnect()
        AppLogger.shared.info("[AuthService] User signed out, credentials wiped from Keychain")
    }
}
