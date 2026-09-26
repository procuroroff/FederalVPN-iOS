import Foundation
import Combine

@MainActor
public final class ServerListViewModel: ObservableObject {
    @Published public var servers: [Server] = []
    @Published public var selectedServer: Server?
    @Published public var isAutoSelecting: Bool = false
    @Published public var isRefreshing: Bool = false
    
    private let serverRepo = ServerRepository.shared
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        bindObservables()
    }
    
    private func bindObservables() {
        serverRepo.$servers
            .receive(on: RunLoop.main)
            .assign(to: \.servers, on: self)
            .store(in: &cancellables)
        
        serverRepo.$selectedServer
            .receive(on: RunLoop.main)
            .assign(to: \.selectedServer, on: self)
            .store(in: &cancellables)
        
        serverRepo.$isRefreshing
            .receive(on: RunLoop.main)
            .assign(to: \.isRefreshing, on: self)
            .store(in: &cancellables)
    }
    
    public func selectServer(_ server: Server) {
        serverRepo.selectServer(server)
    }
    
    public func performAutoSelection(completion: @escaping (Server?) -> Void) {
        isAutoSelecting = true
        Task {
            let best = await serverRepo.performAutomaticSelection()
            await MainActor.run {
                self.isAutoSelecting = false
                completion(best)
            }
        }
    }
    
    public func refreshPings() {
        Task {
            await serverRepo.pingAllServers()
        }
    }
}
