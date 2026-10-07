import ActivityKit

@available(iOS 16.1, *)
struct RadioLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var status: String
    }

    var sessionID: String
}
