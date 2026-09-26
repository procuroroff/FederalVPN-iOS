import Foundation

/// Параметры защищенного сетевого подключения
public struct ConnectionConfig: Codable, Equatable {
    public let serverAddress: String
    public let serverPort: Int
    public let userId: String
    public let transport: String
    public let securityMode: String
    public let serverName: String
    public let publicKey: String
    public let shortId: String
    public let fingerprint: String
    public let flow: String
    
    // Сетевые настройки туннеля (TUN interface)
    public let tunnelIPv4: String
    public let tunnelSubnetMask: String
    public let tunnelIPv6: String
    public let tunnelIPv6PrefixLength: Int
    public let dnsServers: [String]
    public let mtu: Int

    public init(
        serverAddress: String,
        serverPort: Int,
        userId: String,
        transport: String = "tcp",
        securityMode: String = "reality",
        serverName: String = "www.microsoft.com",
        publicKey: String = "PLACEHOLDER_PUBLIC_KEY",
        shortId: String = "PLACEHOLDER_SHORT_ID",
        fingerprint: String = "chrome",
        flow: String = "xtls-rprx-vision",
        tunnelIPv4: String = "10.8.0.2",
        tunnelSubnetMask: String = "255.255.255.0",
        tunnelIPv6: String = "fdfe:dcba:9876::2",
        tunnelIPv6PrefixLength: Int = 64,
        dnsServers: [String] = ["1.1.1.1", "8.8.8.8"],
        mtu: Int = 1400
    ) {
        self.serverAddress = serverAddress
        self.serverPort = serverPort
        self.userId = userId
        self.transport = transport
        self.securityMode = securityMode
        self.serverName = serverName
        self.publicKey = publicKey
        self.shortId = shortId
        self.fingerprint = fingerprint
        self.flow = flow
        self.tunnelIPv4 = tunnelIPv4
        self.tunnelSubnetMask = tunnelSubnetMask
        self.tunnelIPv6 = tunnelIPv6
        self.tunnelIPv6PrefixLength = tunnelIPv6PrefixLength
        self.dnsServers = dnsServers
        self.mtu = mtu
    }

    /// Безопасная тестовая конфигурация с заполнителями (placeholder values)
    public static var placeholder: ConnectionConfig {
        ConnectionConfig(
            serverAddress: "SERVER_ADDRESS",
            serverPort: 443,
            userId: "00000000-0000-0000-0000-000000000000",
            transport: "tcp",
            securityMode: "reality",
            serverName: "www.apple.com",
            publicKey: "PUBLIC_KEY_PLACEHOLDER_32BYTES_LONG",
            shortId: "0123456789abcdef",
            fingerprint: "chrome",
            flow: "xtls-rprx-vision"
        )
    }

    /// Генерация JSON-конфигурации для передачи в Xray/Sing-box core
    public func generateEngineConfigJSON() -> String {
        return """
        {
          "log": { "loglevel": "warning" },
          "inbounds": [
            {
              "tag": "tun-in",
              "port": 10808,
              "listen": "127.0.0.1",
              "protocol": "socks",
              "settings": { "auth": "noauth", "udp": true }
            }
          ],
          "outbounds": [
            {
              "tag": "proxy",
              "protocol": "vless",
              "settings": {
                "vnext": [
                  {
                    "address": "\(serverAddress)",
                    "port": \(serverPort),
                    "users": [
                      {
                        "id": "\(userId)",
                        "encryption": "none",
                        "flow": "\(flow)"
                      }
                    ]
                  }
                ]
              },
              "streamSettings": {
                "network": "\(transport)",
                "security": "\(securityMode)",
                "realitySettings": {
                  "show": false,
                  "serverName": "\(serverName)",
                  "publicKey": "\(publicKey)",
                  "shortId": "\(shortId)",
                  "spiderX": ""
                },
                "sockopt": {
                  "mark": 255
                }
              }
            },
            { "tag": "direct", "protocol": "freedom" }
          ]
        }
        """
    }
}
