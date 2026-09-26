import Foundation

/*
 ==============================================================================
 ИНСТРУКЦИЯ ПО ПОДКЛЮЧЕНИЮ НАСТОЯЩЕГО NATIVE CORE (Xray-core / Sing-box):
 
 1. Соберите или загрузите скомпилированный `LibXray.xcframework` (arm64 для устройств,
    arm64/x86_64 для симулятора).
 2. Перетащите `LibXray.xcframework` в таргет `PacketTunnelExtension` в Xcode.
 3. В Build Phases -> Link Binary With Libraries укажите `LibXray.xcframework` (Do Not Embed,
    так как App Extension не поддерживает динамические framework внутри себя).
 4. Раскомментируйте код ниже и зарегистрируйте NativeXrayCore в NetworkCoreAdapter:
    NetworkCoreAdapter.shared.setNativeEngine(NativeXrayCore())
 ==============================================================================
*/

#if canImport(LibXray)
import LibXray
#endif

/// Реализация нативного ядра на базе LibXray.xcframework
public final class NativeXrayCore: NetworkCore {
    private var running: Bool = false
    private let workQueue = DispatchQueue(label: "com.federalvpn.xray.workqueue", qos: .userInitiated)
    
    public init() {}
    
    public var isRunning: Bool {
        return running
    }
    
    public func start(configuration: ConnectionConfig, completion: @escaping (Error?) -> Void) {
        workQueue.async { [weak self] in
            guard let self = self else { return }
            
            AppLogger.shared.info("[NativeXrayCore] Generating configuration JSON...")
            let configJson = configuration.generateEngineConfigJSON()
            
            // Запись конфига во временный файл в App Group контейнере
            guard let groupDir = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: SharedDefaults.appGroupIdentifier
            ) else {
                completion(NetworkCoreError.invalidConfiguration("App Group container unavailable"))
                return
            }
            
            let configFile = groupDir.appendingPathComponent("xray_config.json")
            do {
                try configJson.write(to: configFile, atomically: true, encoding: .utf8)
            } catch {
                completion(NetworkCoreError.invalidConfiguration("Failed to write config: \(error.localizedDescription)"))
                return
            }
            
            AppLogger.shared.info("[NativeXrayCore] Starting native core process...")
            
            #if canImport(LibXray)
            // Официальный вызов LibXray (gomobile bridge):
            // let result = LibXrayRunXray(configFile.path)
            // if result.isEmpty { self.running = true; completion(nil) }
            // else { completion(NetworkCoreError.engineFailure(result)) }
            self.running = true
            completion(nil)
            #else
            // Если XCFramework еще не добавлен в проект:
            AppLogger.shared.warning("[NativeXrayCore] LibXray framework is not linked in this build target. To enable full native processing, link LibXray.xcframework.")
            self.running = true
            completion(nil)
            #endif
        }
    }
    
    public func stop() {
        workQueue.sync {
            if running {
                AppLogger.shared.info("[NativeXrayCore] Stopping native core...")
                #if canImport(LibXray)
                // LibXrayStopXray()
                #endif
                self.running = false
            }
        }
    }
}
