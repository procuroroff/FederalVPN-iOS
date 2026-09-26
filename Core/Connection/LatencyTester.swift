import Foundation
import Network

/// Утилита для замера задержки (Ping / TCP Handshake latency) до серверов
public final class LatencyTester {
    public static let shared = LatencyTester()
    
    private init() {}
    
    /// Замер TCP задержки до указанного адреса и порта
    public func measureLatency(host: String, port: Int, timeout: TimeInterval = 2.0, completion: @escaping (Int?) -> Void) {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(integerLiteral: UInt16(port))
        )
        
        let parameters = NWParameters.tcp
        let connection = NWConnection(to: endpoint, using: parameters)
        
        var hasCompleted = false
        let timer = DispatchSource.makeTimerSource(queue: .global())
        timer.schedule(deadline: .now() + timeout)
        timer.setEventHandler {
            if !hasCompleted {
                hasCompleted = true
                connection.cancel()
                completion(nil)
            }
        }
        timer.resume()
        
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                if !hasCompleted {
                    hasCompleted = true
                    timer.cancel()
                    let elapsed = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
                    connection.cancel()
                    completion(max(1, elapsed))
                }
            case .failed, .cancelled:
                if !hasCompleted {
                    hasCompleted = true
                    timer.cancel()
                    completion(nil)
                }
            default:
                break
            }
        }
        
        connection.start(queue: .global())
    }
    
    /// Асинхронная версия для Swift Concurrency
    public func measureLatencyAsync(host: String, port: Int, timeout: TimeInterval = 2.0) async -> Int? {
        await withCheckedContinuation { continuation in
            measureLatency(host: host, port: port, timeout: timeout) { result in
                continuation.resume(returning: result)
            }
        }
    }
}
