import SwiftUI
import Combine

// MARK: - Bubble overlay (default style)

struct RecordingOverlayView: View {
    @ObservedObject var manager: TranscriptionManager

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(manager.jobs.enumerated()), id: \.element.id) { index, job in
                JobRowView(job: job, compact: false)
                if index < manager.jobs.count - 1 {
                    Divider()
                        .background(Color.white.opacity(0.12))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

// MARK: - Dynamic Island overlay

struct DynamicIslandOverlayView: View {
    @ObservedObject var manager: TranscriptionManager

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(manager.jobs.enumerated()), id: \.element.id) { index, job in
                JobRowView(job: job, compact: true)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.85, anchor: .top)),
                            removal: .opacity.combined(with: .scale(scale: 0.85, anchor: .top))
                        )
                    )
                if index < manager.jobs.count - 1 {
                    Divider()
                        .background(Color.white.opacity(0.15))
                        .transition(.opacity)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.black)               // solid black to blend with notch
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .animation(.spring(response: 0.38, dampingFraction: 0.72), value: manager.jobs.count)
    }
}

// MARK: - Per-job row

struct JobRowView: View {
    @ObservedObject var job: TranscriptionJob
    var compact: Bool = false

    @State private var audioLevels: [CGFloat] = Array(repeating: 0.1, count: 14)
    // Use .default run-loop mode so the timer never fires during CoreAudio callbacks
    @State private var timerSubscription: AnyCancellable? = nil

    private var iconSize: CGFloat { compact ? 18 : 22 }
    private var rowHeight: CGFloat { compact ? 36 : 40 }
    private var barCount: Int { compact ? 10 : 14 }

    var body: some View {
        HStack(spacing: compact ? 6 : 8) {
            // Target app icon
            if let icon = job.appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: iconSize, height: iconSize)
                    .clipShape(RoundedRectangle(cornerRadius: compact ? 4 : 5, style: .continuous))
            }

            // State indicator
            Group {
                switch job.state {
                case .recording:
                    HStack(spacing: 2) {
                        ForEach(0..<barCount, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color.white)
                                .frame(width: 2, height: max(3, audioLevels[min(i, audioLevels.count - 1)] * 26))
                        }
                    }
                    .frame(height: 26)

                case .queued:
                    HStack(spacing: 5) {
                        HStack(spacing: 2) {
                            ForEach(0..<6, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Color.white.opacity(0.25))
                                    .frame(width: 2, height: 8)
                            }
                        }
                        Text("Queued")
                            .font(.system(size: compact ? 10 : 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.45))
                    }

                case .transcribing:
                    ShimmerText(message: "Transcribing", fontSize: compact ? 11 : 12)

                case .postProcessing(let msg):
                    ShimmerText(message: msg, fontSize: compact ? 11 : 12)
                }
            }
        }
        .frame(height: rowHeight)
        .onAppear {
            // Start timer only when the row appears; use .default mode (not .common)
            // so it never fires during CoreAudio run-loop processing.
            let pub = Timer.publish(every: 0.1, on: .main, in: .default).autoconnect()
            timerSubscription = pub.sink { _ in
                guard case .recording = job.state else { return }
                let level = job.recorder.updateMeters()
                let normalized = CGFloat(max(0.1, (level + 60) / 60))
                withAnimation(.spring(response: 0.1, dampingFraction: 0.5)) {
                    audioLevels.removeFirst()
                    audioLevels.append(normalized)
                }
            }
        }
        .onDisappear {
            timerSubscription?.cancel()
            timerSubscription = nil
        }
    }
}

// MARK: - Shimmer text (shared for transcribing / post-processing states)

struct ShimmerText: View {
    let message: String
    var fontSize: CGFloat = 12

    var body: some View {
        TimelineView(.animation) { timeline in
            let duration: TimeInterval = 1.5
            let elapsed = timeline.date.timeIntervalSinceReferenceDate
            let phase = CGFloat(elapsed.truncatingRemainder(dividingBy: duration) / duration)

            Text(message)
                .font(.system(size: fontSize, weight: .medium))
                .foregroundColor(.white.opacity(0.3))
                .overlay(
                    GeometryReader { geo in
                        let width = geo.size.width
                        let maskWidth = width * 0.7
                        Text(message)
                            .font(.system(size: fontSize, weight: .medium))
                            .foregroundColor(.white)
                            .mask(
                                LinearGradient(
                                    gradient: Gradient(colors: [.clear, .white, .clear]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .frame(width: maskWidth)
                                .offset(x: -maskWidth + (phase * (width + maskWidth)))
                            )
                    }
                )
        }
    }
}
