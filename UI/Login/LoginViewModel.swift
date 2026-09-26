import Foundation
import Combine

@MainActor
public final class LoginViewModel: ObservableObject {
    @Published public var username: String = ""
    @Published public var password: String = ""
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    
    private let authService = AuthService.shared
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        authService.$isLoading
            .receive(on: RunLoop.main)
            .assign(to: \.isLoading, on: self)
            .store(in: &cancellables)
        
        authService.$errorMessage
            .receive(on: RunLoop.main)
            .assign(to: \.errorMessage, on: self)
            .store(in: &cancellables)
    }
    
    public func signIn(completion: @escaping (Bool) -> Void) {
        Task {
            let success = await authService.signIn(username: username, password: password)
            await MainActor.run {
                completion(success)
            }
        }
    }
}
