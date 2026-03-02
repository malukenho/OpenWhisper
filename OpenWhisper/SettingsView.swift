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
                    Text("FFmpeg Path:")
                        .font(.caption)
                    TextField("e.g. /opt/homebrew/bin/ffmpeg", text: $manager.ffmpegPath)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            
            Text("Tip: You can find these by running 'which whisper' and 'which ffmpeg' in your terminal.")
                .font(.caption2)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 15) {
                Text("Whisper Configuration")
                    .font(.subheadline)
                    .fontWeight(.bold)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Model:")
                        .font(.caption)
                    Picker("Model", selection: $manager.whisperModel) {
                        Text("tiny").tag("tiny")
                        Text("tiny.en (English only)").tag("tiny.en")
                        Text("base (default)").tag("base")
                        Text("base.en (English only)").tag("base.en")
                        Text("small").tag("small")
                        Text("small.en (English only)").tag("small.en")
                        Text("medium").tag("medium")
                        Text("medium.en (English only)").tag("medium.en")
                        Text("large").tag("large")
                        Text("large-v2").tag("large-v2")
                        Text("large-v3").tag("large-v3")
                        Text("turbo").tag("turbo")
                    }
                    .pickerStyle(.menu)
                    Text("Larger models are more accurate but slower. English-only models are faster for English.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("Language:")
                        .font(.caption)
                    Picker("Language", selection: $manager.whisperLanguage) {
                        Text("Auto-detect").tag("")
                        Divider()
                        Text("English (en)").tag("en")
                        Text("Spanish (es)").tag("es")
                        Text("French (fr)").tag("fr")
                        Text("German (de)").tag("de")
                        Text("Italian (it)").tag("it")
                        Text("Portuguese (pt)").tag("pt")
                        Text("Dutch (nl)").tag("nl")
                        Text("Russian (ru)").tag("ru")
                        Text("Chinese (zh)").tag("zh")
                        Text("Japanese (ja)").tag("ja")
                        Text("Korean (ko)").tag("ko")
                        Text("Arabic (ar)").tag("ar")
                        Text("Hindi (hi)").tag("hi")
                        Text("Polish (pl)").tag("pl")
                        Text("Ukrainian (uk)").tag("uk")
                        Text("Swedish (sv)").tag("sv")
                        Text("Norwegian (no)").tag("no")
                        Text("Danish (da)").tag("da")
                        Text("Finnish (fi)").tag("fi")
                        Text("Turkish (tr)").tag("tr")
                    }
                    .pickerStyle(.menu)
                    Text("Setting a language skips auto-detection and can improve accuracy and speed.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("Initial Prompt (optional):")
                        .font(.caption)
                    TextField("e.g. The following is a software engineering conversation.", text: $manager.whisperInitialPrompt)
                        .textFieldStyle(.roundedBorder)
                    Text("Provides context to Whisper to improve accuracy for domain-specific terms.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            
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
        .frame(width: 400, height: 900)
    }
}
