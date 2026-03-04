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
    var audioURL: URL?
    let recorder = AudioRecorder()
    let startedAt = Date()

    init(targetApp: NSRunningApplication?) {
        self.targetApp = targetApp
        self.appIcon = targetApp?.icon
    }
}
