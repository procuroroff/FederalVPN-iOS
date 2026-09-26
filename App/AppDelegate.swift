import UIKit

public final class AppDelegate: NSObject, UIApplicationDelegate {
    public func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        AppLogger.shared.info("[AppDelegate] Application finished launching")
        return true
    }
    
    public func applicationDidEnterBackground(_ application: UIApplication) {
        AppLogger.shared.info("[AppDelegate] Application entered background")
    }
    
    public func applicationWillEnterForeground(_ application: UIApplication) {
        AppLogger.shared.info("[AppDelegate] Application entering foreground, refreshing VPN state")
        VPNManager.shared.refreshTunnelManager()
    }
}
