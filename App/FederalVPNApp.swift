import SwiftUI

@main
struct FederalVPNApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // Инициализация логгера и хранилища
        AppLogger.shared.info("[App] Federal VPN launched")
        
        // Предзагрузка серверов из кэша или пресетов
        if ServerRepository.shared.servers.isEmpty {
            Task {
                await ServerRepository.shared.refreshServers(from: "")
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(.dark)
                .onAppear {
                    // Обработка настройки "Подключаться при запуске"
                    if SharedDefaults.shared.isConnectOnLaunchEnabled {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            if let server = ServerRepository.shared.selectedServer ?? ServerRepository.shared.servers.first {
                                let config = ServerRepository.shared.configForServer(server)
                                VPNManager.shared.connect(server: server, config: config)
                            }
                        }
                    }
                }
        }
    }
}
