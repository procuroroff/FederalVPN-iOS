import Foundation
import Combine

@MainActor
public final class HomeViewModel: ObservableObject {
    @Published public var connectionStatus: ConnectionStatus = .disconnected
    @Published public var selectedServer: Server?
    @Published public var formattedDuration: String = "00:00:00"
    @Published public var errorMessage: String?
    
    private let vpnManager = VPNManager.shared
    private let serverRepo = ServerRepository.shared
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        bindObservables()
    }
    
    private func bindObservables() {
        vpnManager.$status
            .receive(on: RunLoop.main)
            .assign(to: \.connectionStatus, on: self)
            .store(in: &cancellables)
        
        vpnManager.$connectionDuration
            .receive(on: RunLoop.main)
            .map { duration -> String in
                let hours = duration / 3600
                let minutes = (duration % 3600) / 60
                let seconds = duration % 60
                return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
            }
            .assign(to: \.formattedDuration, on: self)
            .store(in: &cancellables)
        
        vpnManager.$lastError
            .receive(on: RunLoop.main)
            .assign(to: \.errorMessage, on: self)
            .store(in: &cancellables)
        
        serverRepo.$selectedServer
            .receive(on: RunLoop.main)
            .assign(to: \.selectedServer, on: self)
            .store(in: &cancellables)
    }
    
    public func toggleConnection() {
        if connectionStatus == .connected || connectionStatus == .connecting {
            vpnManager.disconnect()
        } else {
            guard let server = selectedServer ?? serverRepo.servers.first else {
                errorMessage = "Нет доступных серверов"
                return
            }
            let config = serverRepo.configForServer(server)
            vpnManager.connect(server: server, config: config)
        }
    }
}
