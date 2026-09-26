import Foundation
import Combine

/// Сервис авторизации пользователей через бэкенд federal-vpn.site
public final class AuthService: ObservableObject {
    public static let shared = AuthService()
    
    @Published public private(set) var isAuthenticated: Bool = false
    @Published public private(set) var currentUserProfile: UserProfile?
    @Published public private(set) var isLoading: Bool = false
    @Published public var errorMessage: String?
    
    private let baseUrl = "https://federal-vpn.site"
    private let keychain = KeychainManager.shared
    private let defaults = SharedDefaults.shared
    
    private init() {
        restoreSession()
    }
    
    /// Восстановление сохранённой сессии
    public func restoreSession() {
        // Проверяем сохраненный профиль
        if let data = UserDefaults.standard.data(forKey: "saved_user_profile"),
           let cached = try? JSONDecoder().decode(UserProfile.self, from: data) {
            self.currentUserProfile = cached
            self.isAuthenticated = true
            AppLogger.shared.info("[AuthService] Restored profile for '\(cached.username)', days: \(cached.formattedDaysRemaining)")
            
            // Фоновое обновление профиля с сервера
            Task {
                await self.fetchProfile()
            }
        }
    }
    
    /// Авторизация через реальный API federal-vpn.site
    public func signIn(username: String, password: String) async -> Bool {
        let cleanLogin = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPass = password.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanLogin.isEmpty, !cleanPass.isEmpty else {
            await MainActor.run { self.errorMessage = "Заполните все поля" }
            return false
        }
        
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        AppLogger.shared.info("[AuthService] Attempting login for '\(cleanLogin)' to \(baseUrl)/api/login")
        
        guard let url = URL(string: "\(baseUrl)/api/login") else {
            await MainActor.run {
                self.errorMessage = "Неверный URL сервера"
                self.isLoading = false
            }
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let payload: [String: String] = ["login": cleanLogin, "password": cleanPass]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError("Invalid HTTP response")
            }
            
            // Сохранение сессионных кук (fvpn_session)
            if let headerFields = httpResponse.allHeaderFields as? [String: String],
               let responseUrl = httpResponse.url {
                let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: responseUrl)
                for cookie in cookies where cookie.name.contains("session") || cookie.name == "fvpn_session" {
                    _ = keychain.save(key: .authToken, string: cookie.value)
                    AppLogger.shared.info("[AuthService] Saved session cookie to Keychain")
                }
            }
            
            let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            let isOk = json["ok"] as? Bool ?? false
            
            if !isOk {
                let msg = json["message"] as? String ?? "Неверный логин или пароль"
                await MainActor.run {
                    self.errorMessage = msg
                    self.isLoading = false
                }
                AppLogger.shared.warning("[AuthService] Login failed: \(msg)")
                return false
            }
            
            AppLogger.shared.info("[AuthService] Credentials verified, fetching /api/me...")
            let profileSuccess = await self.fetchProfile(fallbackLogin: cleanLogin)
            
            await MainActor.run {
                self.isLoading = false
                self.isAuthenticated = profileSuccess
            }
            return profileSuccess
            
        } catch {
            AppLogger.shared.error("[AuthService] Network error during login: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = "Ошибка подключения к серверу авторизации"
                self.isLoading = false
            }
            return false
        }
    }
    
    /// Запрос актуального профиля /api/me
    public func fetchProfile(fallbackLogin: String = "") async -> Bool {
        guard let url = URL(string: "\(baseUrl)/api/me") else { return false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if let token = keychain.getString(key: .authToken) {
            request.setValue("fvpn_session=\(token)", forHTTPHeaderField: "Cookie")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return false
            }
            
            guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let isOk = root["ok"] as? Bool, isOk else {
                return false
            }
            
            let account = root["account"] as? [String: Any]
            let sub = root["subscription"] as? [String: Any]
            
            let login = (account?["login"] as? String) ?? fallbackLogin
            let status = (sub?["status"] as? String) ?? "ACTIVE"
            let daysLeft = (sub?["days_left"] as? Int) ?? -1
            let expireAt = sub?["expire_at"] as? String
            let subUrl = sub?["subscription_url"] as? String
            
            let profile = UserProfile(
                username: login.isEmpty ? "director" : login,
                accountStatus: status,
                daysLeft: daysLeft,
                expireAt: expireAt,
                subscriptionEndpoint: subUrl
            )
            
            await MainActor.run {
                self.currentUserProfile = profile
                self.isAuthenticated = true
            }
            
            // Кэшируем профиль
            if let enc = try? JSONEncoder().encode(profile) {
                UserDefaults.standard.set(enc, forKey: "saved_user_profile")
            }
            
            AppLogger.shared.info("[AuthService] Profile loaded: \(profile.username), status: \(profile.accountStatus), days: \(profile.formattedDaysRemaining), sub: \(subUrl ?? "none")")
            
            // Если получен URL подписки — обновляем список серверов
            if let subUrl = subUrl, !subUrl.isEmpty {
                Task {
                    await ServerRepository.shared.refreshServers(from: subUrl)
                }
            }
            
            return true
        } catch {
            AppLogger.shared.warning("[AuthService] Failed to fetch /api/me: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Выход из аккаунта
    public func signOut() {
        _ = keychain.delete(key: .authToken)
        _ = keychain.delete(key: .userPassword)
        UserDefaults.standard.removeObject(forKey: "saved_user_profile")
        currentUserProfile = nil
        isAuthenticated = false
        VPNManager.shared.disconnect()
        AppLogger.shared.info("[AuthService] User signed out, cache wiped")
        
        // Возвращаемся к дефолтным пресетам
        ServerRepository.shared.loadDefaultServers()
    }
}
