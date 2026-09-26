import Foundation
import Security

/// Безопасное хранилище конфиденциальных данных в Keychain
public final class KeychainManager {
    public static let shared = KeychainManager()
    
    // Access group для обмена между основным приложением и Extension
    public var accessGroup: String? = nil
    
    private init() {}
    
    public enum KeychainKey: String {
        case authToken = "com.federalvpn.authToken"
        case userPassword = "com.federalvpn.userPassword"
        case activeUserId = "com.federalvpn.activeUserId"
        case activePublicKey = "com.federalvpn.activePublicKey"
    }
    
    public func save(key: KeychainKey, data: Data) -> Bool {
        return save(key: key.rawValue, data: data)
    }
    
    public func save(key: KeychainKey, string: String) -> Bool {
        guard let data = string.data(using: .utf8) else { return false }
        return save(key: key.rawValue, data: data)
    }
    
    public func getString(key: KeychainKey) -> String? {
        guard let data = getData(key: key.rawValue) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    public func delete(key: KeychainKey) -> Bool {
        return delete(key: key.rawValue)
    }
    
    // MARK: - Низкоуровневые методы с поддержкой kSecAttrAccessGroup
    
    public func save(key: String, data: Data) -> Bool {
        // Сначала удаляем старую запись, если существовала
        _ = delete(key: key)
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        if let group = accessGroup {
            query[kSecAttrAccessGroup as String] = group
        }
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    public func getData(key: String) -> Data? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        if let group = accessGroup {
            query[kSecAttrAccessGroup as String] = group
        }
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess {
            return result as? Data
        }
        return nil
    }
    
    public func delete(key: String) -> Bool {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        if let group = accessGroup {
            query[kSecAttrAccessGroup as String] = group
        }
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
