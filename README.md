<div align="center">

# 💬 OpenWhisper

**Your voice, instantly transcribed. Right where you need it.**

OpenWhisper is a free, open-source macOS menu bar app that transcribes your speech locally — no cloud, no subscriptions, no privacy trade-offs. Hold a key, speak, release. Done.

[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black?logo=apple)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange?logo=swift)](https://swift.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

</div>

---

## ✨ Why OpenWhisper?

Tired of switching windows to dictate text? OpenWhisper lives quietly in your menu bar and pastes transcriptions directly into **whatever you're typing in** — your code editor, Slack, email, anything.

- 🔒 **100% local** — Powered by [OpenAI Whisper](https://github.com/openai/whisper) running on *your* machine. Audio never leaves your Mac.
- ⚡ **Instant paste** — Transcription appears right where your cursor is, no copy-paste required.
- 🎯 **Accurate** — Choose from 10+ Whisper models, from lightning-fast `tiny` to studio-grade `large-v3`.
- 🌍 **Multilingual** — Detect language automatically or pin it to one of 20+ supported languages.
- 🧠 **AI post-processing** — Optionally run transcriptions through Gemini AI or a macOS Shortcut before pasting (format code, fix grammar, translate — your rules).
- 🎙️ **Two recording modes** — Push-to-Talk (hold `FN`) or Hands-Free (double-tap `FN`).
- 🔀 **Switch apps freely while transcribing** — The target app is locked in at the moment you start recording. Walk away, switch windows, do something else — OpenWhisper will re-focus the right app and paste when it's done.
- 🪟 **Target app indicator** — The recording overlay shows the icon of the app that will receive the transcription, so you always know where the text is going.

---

## 🖥️ System Requirements

| | |
|---|---|
| **macOS** | 13 Ventura or later |
| **Architecture** | Apple Silicon (M1/M2/M3) or Intel |
| **Dependencies** | `whisper` CLI, `ffmpeg` |

---

## 🚀 Installation

### Step 1 — Install dependencies via Homebrew

```bash
# Install Homebrew if you don't have it
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install ffmpeg
brew install ffmpeg

# Install the openai-whisper Python package
pip3 install openai-whisper
```

> **Apple Silicon users:** Whisper runs natively on the Neural Engine — transcription is fast even on `small` and `medium` models.

### Step 2 — Build OpenWhisper

1. Clone this repository:
   ```bash
   git clone https://github.com/malukenho/open-whisper.git
   cd open-whisper/OpenWhisper
   ```

2. Open the project in Xcode:
   ```bash
   open OpenWhisper.xcodeproj
   ```

3. Press **⌘R** to build and run, or choose **Product → Archive** to create a distributable `.app`.

### Step 3 — First launch

1. **Grant Accessibility permission** — macOS will prompt you. This is required for the global `FN` key hotkey. You can also open *System Settings → Privacy & Security → Accessibility* and enable OpenWhisper manually.

2. **Set binary paths** in Settings (`⌘,`):
   | Field | Default | Find with |
   |---|---|---|
   | Whisper CLI Path | `/opt/homebrew/bin/whisper` | `which whisper` |
   | FFmpeg Path | `/opt/homebrew/bin/ffmpeg` | `which ffmpeg` |

3. You're ready. A **💬 speech bubble** appears in your menu bar.

---

## 🎤 How to Use

### Push-to-Talk (default)
1. Click into any text field in any app
2. **Hold** the `FN` key — recording starts (bubble turns to a mic)
3. **Release** `FN` — Whisper transcribes and the text is pasted instantly

### Hands-Free Mode
1. **Double-tap** `FN` — recording starts
2. **Single-tap** `FN` — recording stops and transcription begins

> 💡 A floating waveform overlay appears while recording so you always know it's listening. The overlay shows the **icon of the target app** — you can freely switch to other apps while Whisper is transcribing and the result will still be pasted into the correct window.

---

## ⚙️ Configuration

Open **Settings** (`⌘,`) from the menu bar icon.

### Whisper Configuration
| Option | Description |
|---|---|
| **Model** | Accuracy vs. speed trade-off. `base` is a great default; `turbo` is fastest; `large-v3` is most accurate. |
| **Language** | Force a language for faster, more accurate results. Leave on *Auto-detect* for multilingual use. |
| **Initial Prompt** | Prime Whisper with domain context, e.g. `"The following is a Swift developer discussing Xcode."` |

### Model Reference
| Model | Speed | Best for |
|---|---|---|
| `tiny` / `tiny.en` | ⚡⚡⚡⚡ | Quick notes, simple dictation |
| `base` / `base.en` | ⚡⚡⚡ | **Recommended default** |
| `small` / `small.en` | ⚡⚡ | Better accuracy, still fast |
| `medium` / `medium.en` | ⚡ | High accuracy |
| `large-v3` | 🐢 | Maximum accuracy |
| `turbo` | ⚡⚡⚡⚡ | Near-`large` quality at `tiny` speed |

### Post-Processing Rules
Route transcriptions through custom logic per app:
- **Pass-through** — paste as-is
- **macOS Shortcut** — run any Shortcut (e.g. grammar fix, translation)
- **Gemini AI** — apply a custom prompt via the Gemini API (API key required)

---

## 🔐 Privacy

OpenWhisper is designed with privacy as a first principle:

- Audio is processed **entirely on-device** using the local Whisper binary
- No audio data is ever uploaded or stored permanently
- The clipboard is automatically restored after pasting if you disable "Copy to clipboard"
- Gemini AI post-processing is **opt-in** and only processes the *text* output, never raw audio

---

## 🛠️ Troubleshooting

**FN key not working**
> Make sure Accessibility permission is granted in *System Settings → Privacy & Security → Accessibility*.

**"Failed to run whisper" in console**
> Verify the Whisper CLI path in Settings. Run `which whisper` in Terminal and paste the result.

**Transcription is slow**
> Switch to a smaller model (`tiny` or `base`) or the `turbo` model in Whisper Configuration settings.

**Wrong language detected**
> Pin the language explicitly in Whisper Configuration settings.

---

## 🤝 Contributing

Pull requests are welcome! For major changes please open an issue first.

1. Fork the repo
2. Create a feature branch: `git checkout -b feat/my-feature`
3. Commit your changes
4. Open a Pull Request

---

## 📄 License

MIT © [Jefersson Nathan](https://github.com/malukenho)

