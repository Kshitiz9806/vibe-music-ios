import Foundation
import Security
import Combine

@MainActor final class SessionStore: ObservableObject {
    @Published private(set) var token: String?
    @Published private(set) var user: User?
    private let service = "app.vibemusic.session"

    init() { token = readToken() }
    func save(_ response: SessionResponse) { token = response.sessionToken; user = response.user; writeToken(response.sessionToken) }
    func clear() { token = nil; user = nil; SecItemDelete([kSecClass: kSecClassGenericPassword, kSecAttrService: service] as CFDictionary) }
    func signOut() async {
        if let token { try? await APIClient.shared.noContent("/auth/logout", method: "POST", token: token) }
        clear()
    }
    func restore() async {
        guard let token else { return }
        do { let response: SessionValidation = try await APIClient.shared.request("/auth/session", token: token); if response.valid { user = response.user } else { clear() } }
        catch APIError.unauthorized { clear() }
        catch { /* Keep the stored session when the API is temporarily unreachable. */ }
    }

    private func readToken() -> String? {
        var result: CFTypeRef?
        let status = SecItemCopyMatching([kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecReturnData: true] as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    private func writeToken(_ token: String) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service]
        SecItemDelete(query as CFDictionary)
        var item = query; item[kSecValueData as String] = Data(token.utf8)
        SecItemAdd(item as CFDictionary, nil)
    }
}
