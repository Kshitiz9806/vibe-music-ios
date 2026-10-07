import ActivityKit
import SwiftUI
import WidgetKit

@available(iOSApplicationExtension 16.1, *)
struct RadioLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RadioLiveActivityAttributes.self) { context in
            HStack(spacing: 12) {
                RadioHeartbeatMark(size: 42)
                VStack(alignment: .leading, spacing: 4) {
                    Text("VibeMusic Radio").font(.headline)
                    Text(context.state.status).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
            }
            .padding(.leading, 16)
            .padding(.trailing, 16)
            .padding(.vertical, 8)
            .activityBackgroundTint(Color.black.opacity(0.9))
            .activitySystemActionForegroundColor(.green)
        } dynamicIsland: { context in
            let statusSymbol = context.state.status == "Playing on Spotify"
                ? "waveform"
                : context.state.status == "Paused on Spotify" ? "pause.fill" : "arrow.triangle.2.circlepath"
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    RadioHeartbeatMark(size: 32)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("VibeMusic Radio").font(.headline)
                        Text(context.state.status).font(.caption).foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Image(systemName: statusSymbol)
                        .foregroundStyle(.green)
                }
            } compactLeading: {
                RadioHeartbeatMark(size: 28)
            } compactTrailing: {
                Image(systemName: statusSymbol)
                    .foregroundStyle(.green)
            } minimal: {
                RadioHeartbeatMark(size: 28)
            }
            .keylineTint(.green)
        }
    }
}

private struct RadioHeartbeatMark: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(Color.black)
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: size * 0.58, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(Color.green)
                .frame(width: size * 0.76, height: size * 0.76)
        }
        .frame(width: size, height: size)
        .overlay {
            Circle().stroke(Color.green.opacity(0.8), lineWidth: max(1, size * 0.04))
        }
        .accessibilityHidden(true)
    }
}

@available(iOSApplicationExtension 16.1, *)
@main
struct VibeMusicLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        RadioLiveActivityWidget()
    }
}
