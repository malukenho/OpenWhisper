import Foundation
import AppKit
import Combine

enum JobState: Equatable {
    case recording
    case queued
    case transcribing
    case postProcessing(String)

    static func == (lhs: JobState, rhs: JobState) -> Bool {
        switch (lhs, rhs) {
        case (.recording, .recording), (.queued, .queued), (.transcribing, .transcribing):
            return true
        case (.postProcessing(let a), .postProcessing(let b)):
            return a == b
        default:
            return false
        }
    }
}

class TranscriptionJob: ObservableObject, Identifiable {
    let id = UUID()
    let targetApp: NSRunningApplication?
    let appIcon: NSImage?
    @Published var state: JobState = .recording
    var audioURL: URL?       // temp WAV path (whisper deletes this after use)
    var savedAudioURL: URL?  // persistent copy saved before whisper runs
    let recorder = AudioRecorder()
    let startedAt = Date()
    /// The specific window (AXUIElement) that was focused at recording start.
    /// Used to raise the exact browser window / terminal tab without activating the app.
    var targetWindow: AXUIElement?
    /// PID of the focused process at recording start, for background paste via CGEventPostToPid.
    var targetPID: pid_t = 0

    init(targetApp: NSRunningApplication?) {
        self.targetApp = targetApp
        self.appIcon = targetApp?.icon
    }
}
