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

/// A shape with flat top corners (to merge seamlessly with the hardware notch)
/// and rounded bottom corners, like the macOS Dynamic Island / Alcove style.
private struct NotchExpandShape: Shape {
    var radius: CGFloat = 22
    func path(in rect: CGRect) -> Path {
        var p = Path()
        // Top edge — completely flat so the view bleeds into the notch
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        // Right edge down to bottom-right curve
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY))
        // Bottom edge
        p.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        // Bottom-left curve
        p.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - radius),
            control: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

struct DynamicIslandOverlayView: View {
    @ObservedObject var manager: TranscriptionManager

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(manager.jobs.enumerated()), id: \.element.id) { index, job in
                DynamicIslandJobRow(job: job)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
                if index < manager.jobs.count - 1 {
                    Rectangle()
                        .fill(Color.white.opacity(0.10))
                        .frame(height: 0.5)
                        .transition(.opacity)
                }
            }
        }
        .background(Color.black)
        .clipShape(NotchExpandShape(radius: 22))
        .animation(.spring(response: 0.4, dampingFraction: 0.78), value: manager.jobs.count)
    }
}

// MARK: - Dynamic Island per-job row (Alcove-style)

struct DynamicIslandJobRow: View {
    @ObservedObject var job: TranscriptionJob

    @State private var audioLevels: [CGFloat] = [0.25, 0.55, 0.80, 0.45, 0.65]
    @State private var timerSub: AnyCancellable? = nil

    private var appName: String {
        job.targetApp?.localizedName ?? "Unknown App"
    }

    var body: some View {
        HStack(spacing: 13) {
            // Large rounded app icon — the visual anchor, like album art in Alcove
            Group {
                if let icon = job.appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                } else {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color.white.opacity(0.12))
                }
            }
            .frame(width: 46, height: 46)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

            // Center: app name (title) + state label (subtitle)
            VStack(alignment: .leading, spacing: 3) {
                Text(appName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                stateLabel
            }

            Spacer(minLength: 6)

            // Right-side live indicator
            stateIndicator
                .frame(width: 46, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .onAppear {
            let pub = Timer.publish(every: 0.1, on: .main, in: .default).autoconnect()
            timerSub = pub.sink { _ in
                guard case .recording = job.state else { return }
                let level = job.recorder.updateMeters()
                let v = CGFloat(max(0.08, (level + 60) / 60))
                withAnimation(.spring(response: 0.12, dampingFraction: 0.5)) {
                    audioLevels = Array(audioLevels.dropFirst()) + [v]
                }
            }
        }
        .onDisappear {
            timerSub?.cancel()
            timerSub = nil
        }
    }

    @ViewBuilder
    private var stateLabel: some View {
        switch job.state {
        case .recording:
            Text("Recording")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.white.opacity(0.55))
        case .queued:
            Text("Queued")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.white.opacity(0.38))
        case .transcribing:
            ShimmerText(message: "Transcribing…", fontSize: 12)
        case .postProcessing(let msg):
            ShimmerText(message: msg, fontSize: 12)
        }
    }

    @ViewBuilder
    private var stateIndicator: some View {
        switch job.state {
        case .recording:
            // Live waveform bars — 5 bars, right-aligned
            HStack(alignment: .center, spacing: 3) {
                ForEach(0..<5, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white)
                        .frame(width: 3, height: max(5, audioLevels[i] * 34))
                }
            }
            .frame(height: 34)
        case .queued:
            Image(systemName: "clock")
                .font(.system(size: 18, weight: .light))
                .foregroundColor(.white.opacity(0.30))
        case .transcribing, .postProcessing:
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(0.7)
                .tint(.white.opacity(0.6))
        }
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
