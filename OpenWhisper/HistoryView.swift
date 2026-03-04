import SwiftUI
import AVFoundation
import Combine

// MARK: - Audio player state (retained for the lifetime of HistoryView)

private final class AudioPlayerState: ObservableObject {
    @Published var playingID: UUID? = nil
    private var player: AVAudioPlayer?

    func toggle(entry: TranscriptionEntry) {
        guard let url = entry.audioURL,
              FileManager.default.fileExists(atPath: url.path) else { return }

        if playingID == entry.id {
            player?.stop()
            player = nil
            playingID = nil
        } else {
            player?.stop()
            do {
                player = try AVAudioPlayer(contentsOf: url)
                player?.play()
                playingID = entry.id
                // Auto-clear when playback finishes
                let id = entry.id
                DispatchQueue.main.asyncAfter(deadline: .now() + (player?.duration ?? 0) + 0.1) { [weak self] in
                    if self?.playingID == id { self?.playingID = nil }
                }
            } catch {
                print("Playback error: \(error)")
            }
        }
    }

    func stop() {
        player?.stop()
        player = nil
        playingID = nil
    }
}

// MARK: - History view

struct HistoryView: View {
    @ObservedObject var manager: TranscriptionManager
    @StateObject private var audioState = AudioPlayerState()
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Transcription History")
                    .font(.headline)
                Spacer()
                Button(action: {
                    audioState.stop()
                    manager.clearAllAudio()
                    manager.history.removeAll()
                    UserDefaults.standard.removeObject(forKey: "transcriptionHistory")
                }) {
                    Text("Clear All")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            if manager.history.isEmpty {
                VStack {
                    Spacer()
                    Text("No history yet")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(manager.history) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(entry.date, style: .date)
                                Text(entry.date, style: .time)
                                if let source = entry.processingSource {
                                    Text("·")
                                    Text(source)
                                        .foregroundColor(.accentColor)
                                }
                                Spacer()
                                // Audio playback button (only when a recording exists)
                                if let url = entry.audioURL,
                                   FileManager.default.fileExists(atPath: url.path) {
                                    let isPlaying = audioState.playingID == entry.id
                                    Button(action: { audioState.toggle(entry: entry) }) {
                                        Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle")
                                            .foregroundColor(isPlaying ? .accentColor : .secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .help(isPlaying ? "Stop playback" : "Play recording")
                                }
                                Button(action: {
                                    copyToClipboard(entry.processedText ?? entry.text)
                                }) {
                                    Image(systemName: "doc.on.doc")
                                }
                                .buttonStyle(.plain)
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)

                            if let processed = entry.processedText {
                                Text(processed)
                                    .font(.body)
                                    .lineLimit(3)
                                    .fixedSize(horizontal: false, vertical: true)
                                Divider()
                                HStack(spacing: 4) {
                                    Text("Original:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(entry.text)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer()
                                    Button(action: { copyToClipboard(entry.text) }) {
                                        Image(systemName: "doc.on.doc")
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundColor(.secondary)
                                }
                            } else {
                                Text(entry.text)
                                    .font(.body)
                                    .lineLimit(3)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.vertical, 4)
                        .contextMenu {
                            Button("Copy") {
                                copyToClipboard(entry.processedText ?? entry.text)
                            }
                            if entry.processedText != nil {
                                Button("Copy Original") {
                                    copyToClipboard(entry.text)
                                }
                            }
                            if let url = entry.audioURL,
                               FileManager.default.fileExists(atPath: url.path) {
                                Button(audioState.playingID == entry.id ? "Stop Playback" : "Play Recording") {
                                    audioState.toggle(entry: entry)
                                }
                            }
                            Button("Delete") {
                                if audioState.playingID == entry.id { audioState.stop() }
                                deleteEntry(entry)
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 400, minHeight: 500)
        .onDisappear { audioState.stop() }
    }
    
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    private func deleteEntry(_ entry: TranscriptionEntry) {
        manager.deleteEntryAudio(entry)
        manager.history.removeAll { $0.id == entry.id }
        if let encoded = try? JSONEncoder().encode(manager.history) {
            UserDefaults.standard.set(encoded, forKey: "transcriptionHistory")
        }
    }
}

#Preview {
    HistoryView(manager: TranscriptionManager())
}
