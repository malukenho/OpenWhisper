import SwiftUI

struct HistoryView: View {
    @ObservedObject var manager: TranscriptionManager
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Transcription History")
                    .font(.headline)
                Spacer()
                Button(action: {
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
                                Spacer()
                                Button(action: {
                                    copyToClipboard(entry.text)
                                }) {
                                    Image(systemName: "doc.on.doc")
                                }
                                .buttonStyle(.plain)
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                            
                            Text(entry.text)
                                .font(.body)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 4)
                        .contextMenu {
                            Button("Copy") {
                                copyToClipboard(entry.text)
                            }
                            Button("Delete") {
                                deleteEntry(entry)
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 400, minHeight: 500)
    }
    
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    private func deleteEntry(_ entry: TranscriptionEntry) {
        manager.history.removeAll { $0.id == entry.id }
        if let encoded = try? JSONEncoder().encode(manager.history) {
            UserDefaults.standard.set(encoded, forKey: "transcriptionHistory")
        }
    }
}

#Preview {
    HistoryView(manager: TranscriptionManager())
}
