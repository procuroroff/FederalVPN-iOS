import Foundation
import os.log

public enum LogLevel: String, Comparable {
    case debug   = "DEBUG"
    case info    = "INFO"
    case warning = "WARNING"
    case error   = "ERROR"
    
    private var priority: Int {
        switch self {
        case .debug:   return 0
        case .info:    return 1
        case .warning: return 2
        case .error:   return 3
        }
    }
    
    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.priority < rhs.priority
    }
}

/// Потокобезопасный централизованный логгер с маскированием конфиденциальных данных
public final class AppLogger {
    public static let shared = AppLogger()
    
    public var minimumLogLevel: LogLevel = .debug
    public var isLoggingEnabled: Bool = true
    
    private let lock = NSLock()
    private var logHistory: [String] = []
    private let maxHistoryEntries = 500
    
    private let subsystem = "com.federalvpn.app"
    private let osLog = OSLog(subsystem: "com.federalvpn.app", category: "ProtectedNetwork")
    
    private init() {}
    
    public func log(_ level: LogLevel, message: String, file: String = #file, function: String = #function, line: Int = #line) {
        guard isLoggingEnabled, level >= minimumLogLevel else { return }
        
        let sanitized = sanitize(message)
        let filename = (file as NSString).lastPathComponent
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let formatted = "[\(timestamp)] [\(level.rawValue)] [\(filename):\(line)] \(sanitized)"
        
        lock.lock()
        logHistory.append(formatted)
        if logHistory.count > maxHistoryEntries {
            logHistory.removeFirst(logHistory.count - maxHistoryEntries)
        }
        lock.unlock()
        
        #if DEBUG
        print(formatted)
        #endif
        
        switch level {
        case .debug:
            os_log("%{public}@", log: osLog, type: .debug, sanitized)
        case .info:
            os_log("%{public}@", log: osLog, type: .info, sanitized)
        case .warning:
            os_log("%{public}@", log: osLog, type: .default, sanitized)
        case .error:
            os_log("%{public}@", log: osLog, type: .error, sanitized)
        }
    }
    
    public func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.debug, message: message, file: file, function: function, line: line)
    }
    
    public func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, message: message, file: file, function: function, line: line)
    }
    
    public func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.warning, message: message, file: file, function: function, line: line)
    }
    
    public func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.error, message: message, file: file, function: function, line: line)
    }
    
    /// Получить историю логов для диагностики (все секреты предварительно отфильтрованы)
    public func exportLogs() -> String {
        lock.lock()
        defer { lock.unlock() }
        return logHistory.joined(separator: "\n")
    }
    
    public func clearLogs() {
        lock.lock()
        defer { lock.unlock() }
        logHistory.removeAll()
    }
    
    /// Автоматическое маскирование паролей, токенов, UUID и приватных ключей
    private func sanitize(_ raw: String) -> String {
        var text = raw
        
        // Маскирование UUID / user ID
        let uuidRegex = #"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"#
        text = text.replacingOccurrences(of: uuidRegex, with: "UUID-REDACTED", options: .regularExpression)
        
        // Маскирование паролей в строках вида password=... или "password": "..."
        let passRegex = #"(password|passwd|pwd|token|secret)[\s:=]+([^\s,;"]+)"#
        text = text.replacingOccurrences(of: passRegex, with: "$1=***REDACTED***", options: [.regularExpression, .caseInsensitive])
        
        // Маскирование длинных base64 ключей (32+ символов)
        let keyRegex = #"(publicKey|privateKey|shortId|baseKey|secretKey)[\s:=]+([a-zA-Z0-9+/=_-]{16,})"#
        text = text.replacingOccurrences(of: keyRegex, with: "$1=KEY-REDACTED", options: [.regularExpression, .caseInsensitive])
        
        return text
    }
}
