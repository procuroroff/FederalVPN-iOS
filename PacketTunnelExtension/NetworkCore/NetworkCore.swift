import Foundation

/// Ошибки сетевого ядра
public enum NetworkCoreError: LocalizedError {
    case alreadyRunning
    case invalidConfiguration(String)
    case engineFailure(String)
    case timeout
    
    public var errorDescription: String? {
        switch self {
        case .alreadyRunning:
            return "Сетевое ядро уже запущено."
        case .invalidConfiguration(let reason):
            return "Неверная конфигурация подключения: \(reason)"
        case .engineFailure(let details):
            return "Сбой нативного ядра: \(details)"
        case .timeout:
            return "Превышено время ожидания запуска ядра."
        }
    }
}

/// Абстрактный протокол сетевого ядра
public protocol NetworkCore: AnyObject {
    func start(
        configuration: ConnectionConfig,
        completion: @escaping (Error?) -> Void
    )
    
    func stop()
    
    var isRunning: Bool { get }
}
