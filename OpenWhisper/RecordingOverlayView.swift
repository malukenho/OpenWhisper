import SwiftUI
import Combine

// MARK: - Overlay root

struct RecordingOverlayView: View {
    @ObservedObject var manager: TranscriptionManager

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(manager.jobs.enumerated()), id: \.element.id) { index, job in
                JobRowView(job: job)
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

// MARK: - Per-job row

struct JobRowView: View {
    @ObservedObject var job: TranscriptionJob
    @State private var audioLevels: [CGFloat] = Array(repeating: 0.1, count: 14)
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 8) {
            // Target app icon
            if let icon = job.appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }

            // State indicator
            Group {
                switch job.state {
                case .recording:
                    HStack(spacing: 2) {
                        ForEach(0..<audioLevels.count, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color.white)
                                .frame(width: 2, height: max(3, audioLevels[i] * 26))
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
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.45))
                    }

                case .transcribing:
                    ShimmerText(message: "Transcribing")

                case .postProcessing(let msg):
                    ShimmerText(message: msg)
                }
            }
        }
        .frame(height: 40)
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

    var body: some View {
        TimelineView(.animation) { timeline in
            let duration: TimeInterval = 1.5
            let elapsed = timeline.date.timeIntervalSinceReferenceDate
            let phase = CGFloat(elapsed.truncatingRemainder(dividingBy: duration) / duration)

            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.3))
                .overlay(
                    GeometryReader { geo in
                        let width = geo.size.width
                        let maskWidth = width * 0.7
                        Text(message)
                            .font(.system(size: 12, weight: .medium))
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
