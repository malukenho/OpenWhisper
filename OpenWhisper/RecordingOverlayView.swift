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
                    let phase = CGFloat(timeline.date.timeIntervalSinceReferenceDate.remainder(dividingBy: 1.5) / 1.5)
                    
                    Text("Transcribing...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                        .overlay(
                            GeometryReader { geo in
                                Text("Transcribing...")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                    .mask(
                                        LinearGradient(
                                            gradient: Gradient(colors: [.clear, .white, .clear]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                        .frame(width: geo.size.width * 0.5)
                                        .offset(x: -geo.size.width + (phase * geo.size.width * 2))
                                    )
                            }
                        )
                }
                .transition(.opacity)
            } else {
                HStack(spacing: 30) {
                    // Cancel Button
                    Button(action: {
                        manager.cancelRecording()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)

                    // Waveform
                    HStack(spacing: 3) {
                        ForEach(0..<audioLevels.count, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white)
                                .frame(width: 3, height: max(4, audioLevels[index] * 40))
                        }
                    }
                    .frame(width: 100, height: 40)

                    // Stop Button
                    Button(action: {
                        manager.toggleRecording()
                    }) {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 25)
        .padding(.vertical, 12)
        .frame(minWidth: 240, minHeight: 64)
        .background(Color.black.opacity(0.8))
        .clipShape(Capsule())
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
