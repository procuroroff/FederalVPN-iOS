import Foundation

/// Тестовая реализация сетевого ядра (Mock) для проверки UI, туннеля и жизненного цикла
public final class MockNetworkCore: NetworkCore {
    private var running: Bool = false
    private let queue = DispatchQueue(label: "com.federalvpn.mockcore", qos: .userInitiated)
    
    public init() {}
    
    public var isRunning: Bool {
        return running
    }
    
    public func start(configuration: ConnectionConfig, completion: @escaping (Error?) -> Void) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            if self.running {
                completion(NetworkCoreError.alreadyRunning)
                return
            }
            
            AppLogger.shared.info("[MockCore] Initializing mock tunnel engine for \(configuration.serverAddress):\(configuration.serverPort)")
            
            // Имитация подготовки сокетов и рукопожатия TLS/REALITY
            Thread.sleep(forTimeInterval: 0.35)
            
            self.running = true
            AppLogger.shared.info("[MockCore] Mock tunnel engine started successfully")
            completion(nil)
        }
    }
    
    public func stop() {
        queue.sync {
            if running {
                AppLogger.shared.info("[MockCore] Stopping mock engine")
                running = false
            }
        }
    }
}
