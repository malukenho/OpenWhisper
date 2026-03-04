import SwiftUI
import Combine

// MARK: - Overlay root

struct RecordingOverlayView: View {
    @ObservedObject var manager: TranscriptionManager

    private var isDynamicIsland: Bool { manager.overlayStyle == "dynamicIsland" }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(manager.jobs.enumerated()), id: \.element.id) { index, job in
                JobRowView(job: job, compact: isDynamicIsland)
                if index < manager.jobs.count - 1 {
                    Divider()
                        .background(Color.white.opacity(0.12))
                }
            }
        }
        .padding(.horizontal, isDynamicIsland ? 10 : 12)
        .padding(.vertical, isDynamicIsland ? 6 : 8)
        .background(Color.black.opacity(isDynamicIsland ? 0.92 : 0.82))
        .clipShape(
            RoundedRectangle(
                cornerRadius: isDynamicIsland ? 20 : 22,
                style: .continuous)
        )
    }
}

// MARK: - Per-job row

struct JobRowView: View {
    @ObservedObject var job: TranscriptionJob
    var compact: Bool = false

    @State private var audioLevels: [CGFloat] = Array(repeating: 0.1, count: 14)
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

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
                        ForEach(0..<(compact ? 10 : 14), id: \.self) { i in
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
        .onReceive(timer) { _ in
            guard case .recording = job.state else { return }
            let level = job.recorder.updateMeters()
            let normalized = CGFloat(max(0.1, (level + 60) / 60))
            withAnimation(.spring(response: 0.1, dampingFraction: 0.5)) {
                audioLevels.removeFirst()
                audioLevels.append(normalized)
            }
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
