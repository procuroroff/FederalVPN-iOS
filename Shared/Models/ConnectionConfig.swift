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

    /// Генерация JSON-конфигурации для передачи в sing-box / Libbox core
    public func generateSingBoxConfigJSON() -> String {
        let server = serverAddress.isEmpty ? "sw1.pornsite.fun" : serverAddress
        let port = serverPort > 0 ? serverPort : 443
        let uuid = userId.isEmpty ? "7ad08a3b-53bb-4902-a0a3-6b6c4f42d019" : userId
        let sni = serverName.isEmpty ? "www.nvidia.com" : serverName
        let rawPbk = publicKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let pbk: String
        if rawPbk.isEmpty || rawPbk.contains("PLACEHOLDER") {
            pbk = "PIJ9YOUeKXNf-CY_y69wBMASbmEHyFHoc6AK_jOF2nw"
        } else {
            pbk = rawPbk.replacingOccurrences(of: " ", with: "+")
        }
        let flowStr = flow.isEmpty ? "xtls-rprx-vision" : flow
        let fp = fingerprint.isEmpty ? "chrome" : fingerprint
        
        return """
        {
          "log": {
            "level": "warn"
          },
          "dns": {
            "servers": [
              {
                "type": "tcp",
                "tag": "dns-remote",
                "server": "1.1.1.1",
                "detour": "proxy"
              },
              {
                "type": "udp",
                "tag": "dns-direct",
                "server": "1.1.1.1"
              }
            ],
            "rules": [
              {
                "outbound": "any",
                "server": "dns-direct"
              }
            ],
            "strategy": "prefer_ipv4"
          },
          "inbounds": [
            {
              "type": "tun",
              "tag": "tun-in",
              "address": [
                "172.19.0.1/30"
              ],
              "mtu": 1500,
              "auto_route": true,
              "strict_route": false,
              "stack": "mixed"
            }
          ],
          "outbounds": [
            {
              "type": "vless",
              "tag": "proxy",
              "server": "\(server)",
              "server_port": \(port),
              "uuid": "\(uuid)",
              "flow": "\(flowStr)",
              "network": "tcp",
              "tls": {
                "enabled": true,
                "server_name": "\(sni)",
                "utls": {
                  "enabled": true,
                  "fingerprint": "\(fp)"
                },
                "reality": {
                  "enabled": true,
                  "public_key": "\(pbk)",
                  "short_id": "\(shortId)"
                }
              }
            },
            {
              "type": "direct",
              "tag": "direct"
            }
          ],
          "route": {
            "rules": [
              {
                "protocol": "dns",
                "action": "hijack-dns"
              }
            ],
            "final": "proxy",
            "auto_detect_interface": true
          }
        }
        """
    }
}
