import Foundation

enum ContextError: LocalizedError {
    case httpError(Int)
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .httpError(let code): return "Server returned HTTP \(code)."
        case .invalidURL: return "Invalid server URL."
        }
    }
}

final class ContextService {
    private let baseURL = AppConfig.backendBaseURL

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    func fetchContext(lat: Double, lon: Double, city: String, timezone: String) async throws -> ContextResponse {
        guard let url = URL(string: "\(baseURL)/context") else {
            throw ContextError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            ContextRequest(lat: lat, lon: lon, city: city, timezone: timezone)
        )

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw ContextError.httpError(http.statusCode)
        }

        return try decoder.decode(ContextResponse.self, from: data)
    }
}
