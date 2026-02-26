import SwiftUI
import Combine

struct SettingsView: View {
    @ObservedObject var manager: TranscriptionManager
    
    var body: some View {
        VStack(spacing: 20) {
            Text("OpenWhisper Settings")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 15) {
                Text("Interaction Model")
                    .font(.subheadline)
                    .fontWeight(.bold)
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        Image(systemName: "mic.fill")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading) {
                            Text("Push-to-Talk")
                                .fontWeight(.medium)
                            Text("Hold the **FN** key to record. Release to stop and transcribe.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack(alignment: .top) {
                        Image(systemName: "waveform")
                            .foregroundColor(.green)
                        VStack(alignment: .leading) {
                            Text("Hands-Free Mode")
                                .fontWeight(.medium)
                            Text("Double-press the **FN** key to start recording. Press **FN** again once to stop.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            
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
                    Text("Required for Global FN Key detection")
                        .font(.caption)
                        .foregroundColor(.red)
                    
                    Button("Open System Settings") {
                        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            
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
            
            Button("Open Post-Processing Rules…") {
                if let delegate = NSApp.delegate as? AppDelegate {
                    delegate.openPostProcessing()
                }
            }
            .buttonStyle(.link)

            VStack(alignment: .leading, spacing: 10) {
                Text("Behaviour")
                    .font(.subheadline)
                    .fontWeight(.bold)

                Toggle(isOn: $manager.copyToClipboardEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Copy result to clipboard & auto-paste")
                            .fontWeight(.medium)
                        Text("When disabled, clipboard is not overwritten.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            
            Spacer()
        }
        .padding()
        .frame(width: 400, height: 600)
    }
}
