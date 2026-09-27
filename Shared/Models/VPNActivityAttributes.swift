import Foundation
#if canImport(ActivityKit)
import ActivityKit

public struct VPNActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var serverName: String
        public var serverFlag: String
        public var serverCountry: String
        public var connectedDate: Date
        
        public init(serverName: String, serverFlag: String, serverCountry: String, connectedDate: Date) {
            self.serverName = serverName
            self.serverFlag = serverFlag
            self.serverCountry = serverCountry
            self.connectedDate = connectedDate
        }
    }
    
    public var appName: String
    
    public init(appName: String = "Federal VPN") {
        self.appName = appName
    }
}
#endif
