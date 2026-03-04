# Changelog

All notable changes to OpenWhisper are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [Unreleased]

### Added
- **Settings revamp with tabs** — Settings is now split across three tabs: **General** (interaction model, accessibility, behaviour), **Whisper** (binary paths, model, language, initial prompt), and **Post-Processing** (inline, no separate window needed). Section cards use the macOS 26 liquid glass material with a graceful fallback for earlier versions.
- **Transcription queue** — Multiple recordings can be queued while a previous one is still being processed by Whisper. Each recording is captured immediately with its own audio stream; transcription runs serially (one Whisper process at a time) so the CPU is not overwhelmed. Results are pasted into the correct target app in the order they were recorded.
- **Multi-job overlay** — The floating recording bubble now stacks one row per active job. Each row shows the target app's icon and a live state indicator: animated waveform bars while recording, dimmed static bars with a "Queued" label while waiting, and the existing shimmer animation while transcribing or running post-processing.
- **Menu bar queue count** — The menu bar menu shows how many jobs are in flight while processing is ongoing.
- **Background-safe paste** — The target application is now captured when recording *starts*, before OpenWhisper takes focus. After transcription finishes the app is re-activated automatically, so the text is always pasted into the correct window even if you switch apps during the (potentially lengthy) transcription process.
- **Target app icon in recording overlay** — Each job row in the overlay shows the icon of the application that will receive the transcription.

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
