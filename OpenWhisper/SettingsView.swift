import SwiftUI
import Combine

// MARK: - Root

struct SettingsView: View {
    @ObservedObject var manager: TranscriptionManager

    var body: some View {
        TabView {
            GeneralSettingsTab(manager: manager)
                .tabItem { Label("General", systemImage: "gear") }

            WhisperSettingsTab(manager: manager)
                .tabItem { Label("Whisper", systemImage: "waveform") }

            PostProcessingSettingsView()
                .tabItem { Label("Post-Processing", systemImage: "wand.and.stars") }
        }
        .frame(width: 500, height: 580)
    }
}

// MARK: - General tab

struct GeneralSettingsTab: View {
    @ObservedObject var manager: TranscriptionManager
    @AppStorage("overlayStyle") private var overlayStyle: String = "bubble"

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // Interaction model
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Interaction Model", systemImage: "keyboard")
                            .font(.headline)

                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "mic.fill")
                                .foregroundColor(.blue)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Push-to-Talk").fontWeight(.medium)
                                Text("Hold **FN** to record. Release to transcribe.")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        }

                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "waveform")
                                .foregroundColor(.green)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Hands-Free").fontWeight(.medium)
                                Text("Double-press **FN** to start. Single press to stop.")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // Accessibility
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Permissions", systemImage: "lock.shield")
                            .font(.headline)

                        HStack {
                            Text("Accessibility:")
                                .font(.subheadline)
                            Text(manager.isAccessibilityTrusted ? "✅ Granted" : "❌ Missing")
                                .font(.subheadline)
                                .foregroundColor(manager.isAccessibilityTrusted ? .green : .red)
                                .bold()
                            Spacer()
                            Button("Check Again") { manager.objectWillChange.send() }
                                .buttonStyle(.link)
                        }

                        if !manager.isAccessibilityTrusted {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Required for the global FN key hotkey.")
                                    .font(.caption).foregroundColor(.red)
                                Button("Open System Settings") {
                                    NSWorkspace.shared.open(
                                        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                                }
                            }
                        }
                    }
                }

                // Overlay style
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Overlay Style", systemImage: "rectangle.on.rectangle")
                            .font(.headline)

                        Picker("Overlay Style", selection: $overlayStyle) {
                            Label("Bubble", systemImage: "bubble.left.fill").tag("bubble")
                            Label("Dynamic Island (beta)", systemImage: "pill.fill").tag("dynamicIsland")
                            Label("D.I. Mini (beta)", systemImage: "rectangle.topthird.inset.filled").tag("dynamicIslandMini")
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()

                        Text(overlayStyle == "dynamicIsland"
                             ? "Positions the overlay at the top of the screen inside the notch area, like a Dynamic Island."
                             : overlayStyle == "dynamicIslandMini"
                             ? "Compact style: expands only left and right of the notch — icon on the left, status on the right."
                             : "Classic floating pill anchored near the bottom of the screen.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                // Behaviour
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Behaviour", systemImage: "slider.horizontal.3")
                            .font(.headline)

                        Toggle(isOn: $manager.copyToClipboardEnabled) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Copy result to clipboard").fontWeight(.medium)
                                Text("When disabled, the clipboard is restored after paste.")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Whisper tab

struct WhisperSettingsTab: View {
    @ObservedObject var manager: TranscriptionManager

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // Paths
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Binary Paths", systemImage: "terminal")
                            .font(.headline)

                        field("Whisper CLI Path", placeholder: "/opt/homebrew/bin/whisper",
                              text: $manager.whisperPath)
                        field("FFmpeg Path", placeholder: "/opt/homebrew/bin/ffmpeg",
                              text: $manager.ffmpegPath)

                        Text("Run `which whisper` and `which ffmpeg` in Terminal to find these.")
                            .font(.caption2).foregroundColor(.secondary)
                    }
                }

                // Model & language
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Whisper Configuration", systemImage: "waveform")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Model").font(.caption).foregroundColor(.secondary)
                            Picker("Model", selection: $manager.whisperModel) {
                                Group {
                                    Text("tiny").tag("tiny")
                                    Text("tiny.en (English only)").tag("tiny.en")
                                    Text("base (default)").tag("base")
                                    Text("base.en (English only)").tag("base.en")
                                    Text("small").tag("small")
                                    Text("small.en (English only)").tag("small.en")
                                }
                                Group {
                                    Text("medium").tag("medium")
                                    Text("medium.en (English only)").tag("medium.en")
                                    Text("large").tag("large")
                                    Text("large-v2").tag("large-v2")
                                    Text("large-v3").tag("large-v3")
                                    Text("turbo").tag("turbo")
                                }
                            }
                            .pickerStyle(.menu).labelsHidden()
                            Text("Larger models are more accurate but slower. `turbo` gives near-large quality at tiny speed.")
                                .font(.caption2).foregroundColor(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Language").font(.caption).foregroundColor(.secondary)
                            Picker("Language", selection: $manager.whisperLanguage) {
                                Text("Auto-detect").tag("")
                                Divider()
                                Text("English").tag("en"); Text("Spanish").tag("es")
                                Text("French").tag("fr"); Text("German").tag("de")
                                Text("Italian").tag("it"); Text("Portuguese").tag("pt")
                                Text("Dutch").tag("nl"); Text("Russian").tag("ru")
                                Text("Chinese").tag("zh"); Text("Japanese").tag("ja")
                                Text("Korean").tag("ko"); Text("Arabic").tag("ar")
                                Text("Hindi").tag("hi"); Text("Polish").tag("pl")
                                Text("Ukrainian").tag("uk"); Text("Swedish").tag("sv")
                                Text("Norwegian").tag("no"); Text("Danish").tag("da")
                                Text("Finnish").tag("fi"); Text("Turkish").tag("tr")
                            }
                            .pickerStyle(.menu).labelsHidden()
                            Text("Pinning a language skips auto-detection and improves speed.")
                                .font(.caption2).foregroundColor(.secondary)
                        }

                        field("Initial Prompt (optional)",
                              placeholder: "e.g. The following is a Swift developer discussing Xcode.",
                              text: $manager.whisperInitialPrompt,
                              caption: "Primes Whisper with context to improve accuracy for domain-specific terms.")
                    }
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func field(_ label: String, placeholder: String, text: Binding<String>, caption: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundColor(.secondary)
            TextField(placeholder, text: text).textFieldStyle(.roundedBorder)
            if let caption = caption {
                Text(caption).font(.caption2).foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Glass card helper

/// A card container that uses the macOS 26 liquid glass effect when available,
/// falling back to a subtle material fill on earlier versions.
struct GlassCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background {
                if #available(macOS 26, *) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.ultraThinMaterial)
                } else {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.secondary.opacity(0.08))
                }
            }
    }
}
