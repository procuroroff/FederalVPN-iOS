import Foundation

public enum APIError: LocalizedError {
    case invalidURL
    case networkError(String)
    case unauthorized
    case serverError(Int)
    case decodingError
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "Некорректный адрес запроса."
        case .networkError(let msg): return "Ошибка сети: \(msg)"
        case .unauthorized: return "Неверный логин или пароль."
        case .serverError(let code): return "Ошибка сервера (код \(code))."
        case .decodingError: return "Ошибка разбора ответа сервера."
        }
    }
}

/// HTTP клиент для выполнения запросов к API
public final class APIClient {
    public static let shared = APIClient()
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15.0
        config.timeoutIntervalForResource = 30.0
        self.session = URLSession(configuration: config)
    }
    
    public func request<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        headers: [String: String] = [:],
        body: Data? = nil
    ) async throws -> T {
        guard let url = URL(string: endpoint) else {
            throw APIError.invalidURL
        }
        
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.httpBody = body
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        for (key, val) in headers {
            req.setValue(val, forHTTPHeaderField: key)
        }
        
        do {
            let (data, response) = try await session.data(for: req)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError("Invalid response")
            }
            
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw APIError.unauthorized
            }
            guard (200...299).contains(httpResponse.statusCode) else {
                throw APIError.serverError(httpResponse.statusCode)
            }
            
            do {
                let decoded = try JSONDecoder().decode(T.self, from: data)
                return decoded
            } catch {
                throw APIError.decodingError
            }
        } catch let err as APIError {
            throw err
        } catch {
            throw APIError.networkError(error.localizedDescription)
        }
    }
    
    public func fetchRawString(url: URL) async throws -> String {
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(500)
        }
        guard let string = String(data: data, encoding: .utf8) else {
            throw APIError.decodingError
        }
        return string
    }
}
