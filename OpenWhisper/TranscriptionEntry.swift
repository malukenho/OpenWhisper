import Foundation

struct TranscriptionEntry: Identifiable, Codable {
    var id = UUID()
    let text: String              // original transcribed text
    let processedText: String?    // post-processed text (nil if same as original)
    let processingSource: String? // e.g. "Shortcut: MyShortcut", "Gemini AI", nil for pass-through
    let date: Date
    var audioURL: URL?            // persistent copy of the recording (nil for old entries)

    init(text: String, processedText: String? = nil, processingSource: String? = nil, date: Date, audioURL: URL? = nil) {
        self.text = text
        self.processedText = processedText
        self.processingSource = processingSource
        self.date = date
        self.audioURL = audioURL
    }
}
