# Changelog

All notable changes to OpenWhisper are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [Unreleased]

### Added
- **Background-safe paste** — The target application is now captured when recording *starts*, before OpenWhisper takes focus. After transcription finishes the app is re-activated automatically, so the text is always pasted into the correct window even if you switch apps during the (potentially lengthy) transcription process.
- **Target app icon in recording overlay** — The recording bubble now shows the icon of the application that will receive the transcription on its left side, giving a clear visual confirmation of where the text will land.

---

## [1.0.0] — initial release

### Added
- Menu bar app with Push-to-Talk (`FN` hold) and Hands-Free (double-tap `FN`) recording modes
- Local transcription via the `openai-whisper` CLI — audio never leaves your Mac
- Floating waveform overlay during recording
- Animated "Transcribing…" indicator during processing
- Post-processing rules per app: pass-through, macOS Shortcut, or Gemini AI
- Transcription history viewer
- Configurable Whisper model, language, and initial prompt
- Clipboard restore option (opt-out of keeping transcription on clipboard)
- Accessibility permission check and prompt in Settings
