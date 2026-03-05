# Changelog

All notable changes to OpenWhisper are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [Unreleased]

### Added
- **Mini Dynamic Island overlay style** — A new compact overlay mode that hugs the hardware notch pill. Left side shows a stack of overlapping app icons for all queued jobs (up to 3, plus a count); right side shows an animated green waveform while recording and a `waveform.and.mic` icon while transcribing. Animates out of the notch with a spring bounce on appearance.

### Fixed
- **Paste targeting** — The target application is now explicitly activated (`activate(options: .activateIgnoringOtherApps)`) before sending Cmd+V, ensuring keyboard focus is restored and the paste always lands in the correct text field. Previously, `postToPid` was used without re-focusing, which silently failed when no input was active.

### Added
- **Audio recording in history** — Every transcription now saves a persistent copy of the original WAV recording to `~/Library/Application Support/OpenWhisper/Recordings/`. A play/pause button (▶ / ⏹) appears in the history list for entries that have audio. Playback stops automatically when the recording finishes. "Clear All" and per-entry delete also remove the associated audio file.
- **Dynamic Island overlay style (beta)** — An alternative overlay mode that positions a compact pill at the very top of the display, inside the MacBook notch/menu-bar area, at a window level above the menu bar. Off by default; toggle in **Settings → General → Overlay Style**. Adapts to both styles: compact rows (36 pt) with smaller icons for Dynamic Island, standard rows (40 pt) for Bubble.
- **Precise window targeting via Accessibility API** — At recording start, OpenWhisper now captures the `AXUIElement` of the focused window (not just the app). When pasting, it raises that specific window within the app's z-order — meaning the correct browser window or iTerm2 pane is always targeted, even if you have multiple open.
- **Background paste** — Transcription results are now injected directly into the target process using `CGEvent.postToPid(_:)` instead of activating the application first. The app you are currently working in stays frontmost; the text silently lands in the original target.
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
