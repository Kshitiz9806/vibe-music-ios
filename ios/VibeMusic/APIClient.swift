import Foundation

enum APIError: LocalizedError {
    case invalidResponse, unauthorized, http(Int, String), noTrack
    var errorDescription: String? {
        switch self {
        case .invalidResponse: "The server returned an invalid response."
        case .unauthorized: "Your session expired. Sign in again."
        case let .http(_, message): message
        case .noTrack: "No tracks are available. Widen your selections and try again."
        }
    }
}

@MainActor final class APIClient {
    static let shared = APIClient()
    private let base = URL(string: Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String ?? "http://127.0.0.1:8080")!
    private init() {}

    func checkHealth() async throws {
        var request = URLRequest(url: makeURL("/health"), timeoutInterval: 12)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard response.statusCode == 200 else { throw APIError.http(response.statusCode, "Backend is still starting.") }
    }

    func request<T: Decodable>(_ path: String, method: String = "GET", body: Encodable? = nil, token: String? = nil) async throws -> T {
        var request = URLRequest(url: makeURL(path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body { request.setValue("application/json", forHTTPHeaderField: "Content-Type"); request.httpBody = try JSONEncoder.api.encode(AnyEncodable(body)) }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if response.statusCode == 204 { throw APIError.noTrack }
        guard (200..<300).contains(response.statusCode) else {
            if response.statusCode == 401 { throw APIError.unauthorized }
            let payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            throw APIError.http(response.statusCode, payload?["message"] as? String ?? "Request failed (\(response.statusCode)).")
        }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }

    func noContent(_ path: String, method: String, body: Encodable? = nil, token: String) async throws {
        var request = URLRequest(url: makeURL(path)); request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body { request.setValue("application/json", forHTTPHeaderField: "Content-Type"); request.httpBody = try JSONEncoder.api.encode(AnyEncodable(body)) }
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard response.statusCode == 204 || (200..<300).contains(response.statusCode) else { throw APIError.http(response.statusCode, "Request failed (\(response.statusCode)).") }
    }

    private func makeURL(_ path: String) -> URL {
        let parts = path.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let url = base.appending(path: String(parts[0]))
        guard parts.count == 2 else { return url }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.percentEncodedQuery = String(parts[1])
        return components.url ?? url
    }
}

private struct AnyEncodable: Encodable { private let encodeValue: (Encoder) throws -> Void; init(_ value: Encodable) { encodeValue = { try value.encode(to: $0) } }; func encode(to encoder: Encoder) throws { try encodeValue(encoder) } }
private extension JSONEncoder { static var api: JSONEncoder { let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; return encoder } }
