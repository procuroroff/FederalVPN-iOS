import Foundation
import Combine

@MainActor
public final class SettingsViewModel: ObservableObject {
    @Published public var isAutoConnect: Bool = false
    @Published public var isConnectOnLaunch: Bool = false
    @Published public var isKillSwitch: Bool = false
    @Published public var customDns: String = "1.1.1.1"
    @Published public var isLoggingEnabled: Bool = true
    @Published public var appVersion: String = "1.0.0 (Build 40)"
    
    @Published public var userProfile: UserProfile?
    @Published public var isRefreshingSubscription: Bool = false
    
    private let defaults = SharedDefaults.shared
    private let authService = AuthService.shared
    private let serverRepo = ServerRepository.shared
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        loadSettings()
        bindObservables()
    }
    
    private func loadSettings() {
        isAutoConnect = defaults.isAutoConnectEnabled
        isConnectOnLaunch = defaults.isConnectOnLaunchEnabled
        isKillSwitch = defaults.isKillSwitchEnabled
        customDns = defaults.customDnsServer
        isLoggingEnabled = defaults.isLoggingEnabled
        
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            appVersion = "\(version) (Build \(build))"
        }
    }
    
    private func bindObservables() {
        authService.$currentUserProfile
            .receive(on: RunLoop.main)
            .assign(to: \.userProfile, on: self)
            .store(in: &cancellables)
    }
    
    public func updateAutoConnect(_ enabled: Bool) {
        isAutoConnect = enabled
        defaults.isAutoConnectEnabled = enabled
    }
    
    public func updateConnectOnLaunch(_ enabled: Bool) {
        isConnectOnLaunch = enabled
        defaults.isConnectOnLaunchEnabled = enabled
    }
    
    public func updateKillSwitch(_ enabled: Bool) {
        isKillSwitch = enabled
        defaults.isKillSwitchEnabled = enabled
    }
    
    public func updateCustomDns(_ dns: String) {
        customDns = dns
        defaults.customDnsServer = dns
    }
    
    public func updateLogging(_ enabled: Bool) {
        isLoggingEnabled = enabled
        defaults.isLoggingEnabled = enabled
        AppLogger.shared.isLoggingEnabled = enabled
    }
    
    public func refreshSubscription() {
        guard let endpoint = userProfile?.configurationEndpoint else { return }
        isRefreshingSubscription = true
        Task {
            await serverRepo.refreshServers(from: endpoint)
            await MainActor.run {
                self.isRefreshingSubscription = false
            }
        }
    }
    
    public func signOut() {
        authService.signOut()
    }
}
