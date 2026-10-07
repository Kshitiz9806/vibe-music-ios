import ActivityKit
import Foundation

@MainActor final class RadioLiveActivityController {
    private var activityID: String?
    private var lastIsPlaying: Bool?

    func start(sessionID: String) {
        guard #available(iOS 16.1, *) else { return }
        startActivity(sessionID: sessionID)
    }

    func update(isPlaying: Bool) {
        guard #available(iOS 16.1, *), let activityID, lastIsPlaying != isPlaying else { return }
        lastIsPlaying = isPlaying
        updateActivity(id: activityID, isPlaying: isPlaying)
    }

    @available(iOS 16.1, *)
    private func updateActivity(id: String, isPlaying: Bool) {
        guard let activity = Activity<RadioLiveActivityAttributes>.activities.first(where: { $0.id == id }) else { return }
        let status = isPlaying ? "Playing on Spotify" : "Paused on Spotify"
        Task {
            if #available(iOS 16.2, *) {
                await activity.update(ActivityContent(state: .init(status: status), staleDate: nil))
            } else {
                await activity.update(using: .init(status: status))
            }
        }
    }

    func end() {
        endAllActivities()
    }

    func endAllActivities() {
        guard #available(iOS 16.1, *) else { return }
        self.activityID = nil
        lastIsPlaying = nil
        let activities = Activity<RadioLiveActivityAttributes>.activities
        Task {
            for activity in activities {
                if #available(iOS 16.2, *) {
                    await activity.end(nil, dismissalPolicy: .immediate)
                } else {
                    await activity.end(using: nil, dismissalPolicy: .immediate)
                }
            }
        }
    }

    @available(iOS 16.1, *)
    private func startActivity(sessionID: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        for existingActivity in Activity<RadioLiveActivityAttributes>.activities {
            Task {
                if #available(iOS 16.2, *) {
                    await existingActivity.end(nil, dismissalPolicy: .immediate)
                } else {
                    await existingActivity.end(using: nil, dismissalPolicy: .immediate)
                }
            }
        }

        let attributes = RadioLiveActivityAttributes(sessionID: sessionID)
        let activity: Activity<RadioLiveActivityAttributes>
        do {
            if #available(iOS 16.2, *) {
                let state = RadioLiveActivityAttributes.ContentState(status: "Connecting to Spotify")
                let content = ActivityContent(state: state, staleDate: nil)
                activity = try Activity.request(attributes: attributes, content: content, pushType: nil)
            } else {
                let state = RadioLiveActivityAttributes.ContentState(status: "Connecting to Spotify")
                activity = try Activity.request(attributes: attributes, contentState: state, pushType: nil)
            }
            activityID = activity.id
            lastIsPlaying = nil
        } catch {
            NSLog("Could not start VibeMusic Live Activity: %@", error.localizedDescription)
        }
    }
}
