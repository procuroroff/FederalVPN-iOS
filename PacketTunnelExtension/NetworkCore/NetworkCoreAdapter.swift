import Foundation

/// Адаптер сетевого ядра — единственная точка интеграции нативного движка
public final class NetworkCoreAdapter: NetworkCore {
    public static let shared = NetworkCoreAdapter()
    
    private var activeEngine: NetworkCore
    private let lock = NSLock()
    
    private init() {
        // По умолчанию используется MockNetworkCore для обеспечения стабильной сборки и тестирования.
        // При подключении XCFramework (например, LibXray.xcframework) достаточно переключить activeEngine.
        self.activeEngine = MockNetworkCore()
    }
    
    public var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return activeEngine.isRunning
    }
    
    /// Переключение на реальный нативный движок (например, при сборке с XCFramework)
    public func setNativeEngine(_ engine: NetworkCore) {
        lock.lock()
        defer { lock.unlock() }
        if activeEngine.isRunning {
            activeEngine.stop()
        }
        self.activeEngine = engine
        AppLogger.shared.info("[NetworkCoreAdapter] Switched active engine to \(type(of: engine))")
    }
    
    public func start(configuration: ConnectionConfig, completion: @escaping (Error?) -> Void) {
        lock.lock()
        let engine = activeEngine
        lock.unlock()
        
        AppLogger.shared.info("[NetworkCoreAdapter] Starting core: \(type(of: engine))")
        engine.start(configuration: configuration) { error in
            if let error = error {
                AppLogger.shared.error("[NetworkCoreAdapter] Core start failed: \(error.localizedDescription)")
            } else {
                AppLogger.shared.info("[NetworkCoreAdapter] Core is running and accepting traffic")
            }
            completion(error)
        }
    }
    
    public func stop() {
        lock.lock()
        let engine = activeEngine
        lock.unlock()
        
        AppLogger.shared.info("[NetworkCoreAdapter] Stopping active core")
        engine.stop()
    }
}
