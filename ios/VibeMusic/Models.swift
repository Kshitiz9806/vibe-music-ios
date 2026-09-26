import Foundation

struct User: Decodable {
    let id: String
    let displayName: String
    var isPremium: Bool?
}
struct SessionValidation: Decodable { let valid: Bool; let user: User }

struct SessionResponse: Decodable {
    let sessionToken: String
    let expiresAt: String
    let user: User
}

struct GenreResponse: Decodable { let genres: [String] }
struct PickerResults: Decodable { let items: [PickerItem] }
struct PickerItem: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let subtitle: String
}
struct RadioResponse: Decodable { let radioSessionId: String }
struct TrackResponse: Decodable { let trackUri: String; let playHistoryId: String }

struct RadioParameters: Encodable {
    let genres: [String]
    let artistIds: [String]
    let albumIds: [String]
}
