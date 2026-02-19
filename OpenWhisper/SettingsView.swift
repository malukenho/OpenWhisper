import SwiftUI
import Combine

struct SettingsView: View {
    @ObservedObject var manager: TranscriptionManager
    @State private var isRecordingShortcut = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Global Shortcut Configuration")
                .font(.headline)
            
            HStack {
                Text("Accessibility Permissions:")
                Text(manager.isAccessibilityTrusted ? "✅ Granted" : "❌ Missing")
                    .foregroundColor(manager.isAccessibilityTrusted ? .green : .red)
                    .bold()
                
                Button("Check Again") {
                    manager.objectWillChange.send()
                }
                .buttonStyle(.link)
            }
            .font(.subheadline)
            
            if !manager.isAccessibilityTrusted {
                VStack(spacing: 8) {
                    Text("Required for Global Hotkey and Text Insertion")
                        .font(.caption)
                        .foregroundColor(.red)
                    
                    Button("Open System Settings") {
                        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Toggle Recording Shortcut:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Button(action: {
                    isRecordingShortcut.toggle()
                }) {
                    Text(isRecordingShortcut ? "Recording... (Press any key)" : shortcutString)
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isRecordingShortcut ? Color.blue : Color.clear, lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 15) {
                Text("Binary Paths")
                    .font(.subheadline)
                    .fontWeight(.bold)
                
                VStack(alignment: .leading, spacing: 5) {
                    Text("Whisper CLI Path:")
                        .font(.caption)
                    TextField("e.g. /opt/homebrew/bin/whisper", text: $manager.whisperPath)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 5) {
                    Text("Dependencies PATH (contains ffmpeg):")
                        .font(.caption)
                    TextField("e.g. /opt/homebrew/bin", text: $manager.binPath)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            
            Text("Tip: You can find these by running 'which whisper' and 'which ffmpeg' in your terminal.")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding()
        .frame(width: 400, height: 450)
        .onAppear {
            // Monitor local events when recording
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if isRecordingShortcut {
                    let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue
                    manager.shortcutKeyCode = Int(event.keyCode)
                    manager.shortcutModifiers = Int(modifiers)
                    manager.setupHotkey() // Re-setup global listener
                    isRecordingShortcut = false
                    return nil // Swallow event
                }
                return event
            }
        }
    }
    
    var shortcutString: String {
        var str = ""
        let modifiers = NSEvent.ModifierFlags(rawValue: UInt(manager.shortcutModifiers))
        if modifiers.contains(.command) { str += "⌘ " }
        if modifiers.contains(.shift) { str += "⇧ " }
        if modifiers.contains(.option) { str += "⌥ " }
        if modifiers.contains(.control) { str += "⌃ " }
        
        str += keyCodeToString(UInt16(manager.shortcutKeyCode))
        return str.isEmpty ? "None" : str
    }
    
    func keyCodeToString(_ keyCode: UInt16) -> String {
        // Very basic mapping for common keys
        switch keyCode {
        case 0x00: return "A"
        case 0x01: return "S"
        case 0x02: return "D"
        case 0x03: return "F"
        case 0x04: return "H"
        case 0x05: return "G"
        case 0x06: return "Z"
        case 0x07: return "X"
        case 0x08: return "C"
        case 0x09: return "V"
        case 0x0B: return "B"
        case 0x0C: return "Q"
        case 0x0D: return "W"
        case 0x0E: return "E"
        case 0x0F: return "R"
        case 0x10: return "Y"
        case 0x11: return "T"
        case 0x1F: return "O"
        case 0x20: return "U"
        case 0x22: return "I"
        case 0x23: return "P"
        case 0x25: return "L"
        case 0x26: return "J"
        case 0x27: return "'"
        case 0x28: return "K"
        case 0x29: return ";"
        case 0x31: return "Space"
        default: return "Key \(keyCode)"
        }
    }
}
