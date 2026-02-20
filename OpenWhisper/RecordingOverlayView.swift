import SwiftUI
import Combine

struct RecordingOverlayView: View {
    @ObservedObject var manager: TranscriptionManager
    @State private var audioLevels: [CGFloat] = Array(repeating: 0.1, count: 20)
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            if manager.isTranscribing {
                TimelineView(.animation) { timeline in
                    // Use truncatingRemainder to ensure phase is always positive [0, 1]
                    let duration: TimeInterval = 1.5
                    let elapsed = timeline.date.timeIntervalSinceReferenceDate
                    let phase = CGFloat(elapsed.truncatingRemainder(dividingBy: duration) / duration)
                    
                    Text("Transcribing...")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.3))
                        .overlay(
                            GeometryReader { geo in
                                let width = geo.size.width
                                // Animate from completely left to completely right
                                // Mask width is 70% of text width
                                let maskWidth = width * 0.7
                                
                                Text("Transcribing...")
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
                .transition(.opacity)
            } else {
                HStack(spacing: 0) {
                    // Waveform
                    HStack(spacing: 2) {
                        ForEach(0..<audioLevels.count, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color.white)
                                .frame(width: 2, height: max(3, audioLevels[index] * 30))
                        }
                    }
                    .frame(width: 80, height: 30)
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 8)
        .frame(minWidth: 120, minHeight: 48)
        .background(Color.black.opacity(0.8))
        .clipShape(Capsule())
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: manager.currentMode)
        .animation(.easeInOut, value: manager.isTranscribing)
        .onReceive(timer) { _ in
            if manager.isRecording {
                let level = manager.getAudioLevel()
                // Power levels typically range from -60dB (quiet) to 0dB (loud)
                // We'll map -60...0 to 0.1...1.0
                let normalized = CGFloat(max(0.1, (level + 60) / 60))
                withAnimation(.spring(response: 0.1, dampingFraction: 0.5)) {
                    audioLevels.removeFirst()
                    audioLevels.append(normalized)
                }
            }
        }
    }
}
