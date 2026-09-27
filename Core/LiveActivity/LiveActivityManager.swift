import Foundation
#if canImport(ActivityKit)
import ActivityKit

public final class LiveActivityManager {
    public static let shared = LiveActivityManager()
    
    #if os(iOS)
    private var currentActivity: Any?
    #endif
    
    private init() {}
    
    public func startLiveActivity(serverName: String, serverFlag: String, serverCountry: String, connectedDate: Date) {
        if #available(iOS 16.1, *) {
            guard ActivityAuthorizationInfo().areActivitiesEnabled else {
                AppLogger.shared.info("[LiveActivity] Activities not enabled on this device/system")
                return
            }
            
            stopLiveActivity()
            
            let attributes = VPNActivityAttributes()
            let contentState = VPNActivityAttributes.ContentState(
                serverName: serverName,
                serverFlag: serverFlag,
                serverCountry: serverCountry,
                connectedDate: connectedDate
            )
            
            do {
                let activity = try Activity<VPNActivityAttributes>.request(
                    attributes: attributes,
                    content: .init(state: contentState, staleDate: nil)
                )
                self.currentActivity = activity
                AppLogger.shared.info("[LiveActivity] Started Live Activity: \(activity.id)")
            } catch {
                AppLogger.shared.warning("[LiveActivity] Request error: \(error.localizedDescription)")
            }
        }
    }
    
    public func stopLiveActivity() {
        if #available(iOS 16.1, *) {
            Task {
                for activity in Activity<VPNActivityAttributes>.activities {
                    await activity.end(dismissalPolicy: .immediate)
                }
            }
            self.currentActivity = nil
            AppLogger.shared.info("[LiveActivity] Stopped Live Activities")
        }
    }
}
#else
public final class LiveActivityManager {
    public static let shared = LiveActivityManager()
    private init() {}
    public func startLiveActivity(serverName: String, serverFlag: String, serverCountry: String, connectedDate: Date) {}
    public func stopLiveActivity() {}
}
#endif
