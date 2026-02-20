import Foundation

struct TranscriptionEntry: Identifiable, Codable {
    var id = UUID()
    let text: String
    let date: Date
}
