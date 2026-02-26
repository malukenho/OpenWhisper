# OpenWhisper – Copilot Instructions

## What this app is

OpenWhisper is a macOS menu bar app (SwiftUI + AppKit) that records audio via the FN key, transcribes it using the local `whisper` CLI, and pastes the result into whatever app was frontmost. Post-processing rules can optionally run the text through a macOS Shortcut or the Gemini AI API before pasting.

## Build

Open `OpenWhisper.xcodeproj` in Xcode and build/run with ⌘R. There is no test suite.

From the command line:
```bash
xcodebuild -scheme OpenWhisper -configuration Debug build
```

## Architecture

`TranscriptionManager` is the central coordinator (`ObservableObject`). Everything flows through it:

1. **Input** – `setupHotkey()` registers a global `NSEvent` monitor for `.flagsChanged` to detect FN key presses. Two modes: Push-to-Talk (hold FN) and Hands-Free (double-tap FN).
2. **Recording** – delegates to `AudioRecorder`, which wraps `AVAudioRecorder` and records to a temp WAV file (16 kHz, mono PCM).
3. **Transcription** – `WhisperService` shells out to the `whisper` CLI binary, writes output to a temp `whisper_output/` directory, reads the resulting `.txt` file, and cleans up.
4. **Post-processing** – `applyPostProcessing(to:)` looks up a `PostProcessingRule` from `PostProcessingStore.shared` using the frontmost app's bundle ID. Actions: pass-through, macOS Shortcut, or Gemini AI.
5. **Text insertion** – text is put onto `NSPasteboard`, then a `CGEvent` Cmd+V keystroke is synthesized to paste into the previously captured frontmost app.

Windows (`SettingsView`, `HistoryView`, `PostProcessingSettingsView`) are created lazily in `AppDelegate` with `isReleasedWhenClosed = false` so they are reused across opens.

## Key conventions

- **Persistence**: `@AppStorage` for simple string settings (`whisperPath`, `binPath`); `UserDefaults` + `JSONEncoder/Decoder` for structured data (transcription history, post-processing rules, Gemini API key).
- **Singleton store**: `PostProcessingStore.shared` is the single source of truth for rules and the Gemini API key. Always use this shared instance rather than creating new ones.
- **Post-processing rule matching**: Rules match by exact bundle ID; `"*"` is the wildcard default. Lookup is in `PostProcessingStore.rule(for:)`.
- **Frontmost app capture**: `capturedApp` is recorded in `start()` *before* the app takes focus, so text can be pasted back to the correct target after transcription completes.
- **External dependencies**: `whisper` (openai-whisper Python package) and `ffmpeg` must be installed and their paths configured by the user. Defaults assume `/opt/homebrew/bin`.
- **Accessibility permission required** for the global FN key monitor (`AXIsProcessTrustedWithOptions`). The app checks and prompts via `SettingsView`.
- **Audio level normalization**: dB values from `AVAudioRecorder` (`-160` to `0`) are mapped to `0.1–1.0` for the animated waveform in `RecordingOverlayView`.
- **RTF handling**: `WhisperService` output is plain text, but `runShortcut` handles RTF/RTFD output from macOS Shortcuts via `NSAttributedString` before pasting.
