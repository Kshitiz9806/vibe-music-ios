import SwiftUI
import Combine

@MainActor final class BackendReadiness: ObservableObject {
    enum State {
        case checking
        case unavailable
        case ready
    }

    @Published private(set) var state: State = .checking
    var isReady: Bool {
        switch state {
        case .ready: return true
        case .checking, .unavailable: return false
        }
    }

    func checkUntilReady() async {
        state = .checking
        let deadline = Date().addingTimeInterval(90)

        while !Task.isCancelled {
            do {
                try await APIClient.shared.checkHealth()
                state = .ready
                return
            } catch {
                guard Date() < deadline else {
                    state = .unavailable
                    return
                }
            }

            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }
    }
}

struct BackendStartupView: View {
    let state: BackendReadiness.State
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            AnimatedWaveform()
                .frame(width: 34, height: 24)
                .accessibilityHidden(true)

            Text(isUnavailable ? "Couldn’t reach VibeMusic" : "Waking up VibeMusic")
                .font(.headline)

            Text(isUnavailable
                 ? "Check your connection and try again."
                 : "Connecting to the radio…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if isUnavailable {
                Button("Try again", action: retry)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.green, in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
    }

    private var isUnavailable: Bool {
        switch state {
        case .unavailable: return true
        case .checking, .ready: return false
        }
    }
}

private struct AnimatedWaveform: View {
    @State private var isAnimating = false
    private let heights: [CGFloat] = [0.38, 0.82, 1.0, 0.58]

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            ForEach(heights.indices, id: \.self) { index in
                Capsule()
                    .fill(Color.green)
                    .frame(width: 4, height: 22)
                    .scaleEffect(y: isAnimating ? heights[index] : 0.28, anchor: .center)
                    .animation(
                        .easeInOut(duration: 0.48)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.11),
                        value: isAnimating
                    )
            }
        }
        .onAppear { isAnimating = true }
    }
}
