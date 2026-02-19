import SwiftUI
import Combine

struct RecordingOverlayView: View {
    @ObservedObject var manager: TranscriptionManager
    @State private var audioLevels: [CGFloat] = Array(repeating: 0.1, count: 20)
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 15) {
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
            .frame(width: 80, height: 40)

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
        .padding(.horizontal, 15)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.8))
        .clipShape(Capsule())
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
