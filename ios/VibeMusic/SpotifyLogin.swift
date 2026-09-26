import AuthenticationServices
import CryptoKit
import UIKit

@MainActor final class SpotifyLogin: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?
    private let clientID = Bundle.main.object(forInfoDictionaryKey: "SPOTIFY_CLIENT_ID") as? String ?? ""
    private let redirectURI = Bundle.main.object(forInfoDictionaryKey: "OAUTH_REDIRECT_URI") as? String ?? "app.vibemusic.ios://oauth-callback"

    func signIn() async throws -> SessionResponse {
        guard !clientID.isEmpty, !clientID.hasPrefix("REPLACE") else { throw APIError.http(500, "Add your Spotify client ID in Config.xcconfig.") }
        NSLog("Spotify OAuth redirect URI: %@", redirectURI)
        let state = Data((0..<32).map { _ in UInt8.random(in: 0...255) }).base64URLEncoded
        let verifier = Data((0..<32).map { _ in UInt8.random(in: 0...255) }).base64URLEncoded
        let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncoded
        guard let callbackScheme = URLComponents(string: redirectURI)?.scheme else { throw APIError.invalidResponse }
        var components = URLComponents(string: "https://accounts.spotify.com/authorize")!
        components.queryItems = [
            .init(name: "client_id", value: clientID), .init(name: "response_type", value: "code"),
            .init(name: "redirect_uri", value: redirectURI), .init(name: "state", value: state),
            .init(name: "scope", value: "user-read-email user-read-private user-top-read user-library-read"),
            .init(name: "code_challenge_method", value: "S256"), .init(name: "code_challenge", value: challenge)
        ]
        guard let url = components.url else { throw APIError.invalidResponse }
        let callback: URL = try await withCheckedThrowingContinuation { continuation in
            let auth = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { url, error in
                if let error { continuation.resume(throwing: error); return }
                guard let url else { continuation.resume(throwing: APIError.invalidResponse); return }
                continuation.resume(returning: url)
            }
            auth.presentationContextProvider = self
            auth.prefersEphemeralWebBrowserSession = false
            self.session = auth
            auth.start()
        }
        guard let parts = URLComponents(url: callback, resolvingAgainstBaseURL: false),
              parts.queryItems?.first(where: { $0.name == "state" })?.value == state else { throw APIError.http(401, "Spotify sign-in could not be verified.") }
        if let message = parts.queryItems?.first(where: { $0.name == "error" })?.value { throw APIError.http(401, message) }
        guard let code = parts.queryItems?.first(where: { $0.name == "code" })?.value else { throw APIError.invalidResponse }
        struct Callback: Encodable { let code: String; let redirectUri: String; let codeVerifier: String }
        return try await APIClient.shared.request("/auth/spotify/callback", method: "POST", body: Callback(code: code, redirectUri: redirectURI, codeVerifier: verifier))
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first ?? UIWindow()
    }
}

private extension Data {
    var base64URLEncoded: String { base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "") }
}
