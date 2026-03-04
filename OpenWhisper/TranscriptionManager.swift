import Foundation
import SwiftUI
import AppKit
import Combine
import AVFoundation

class TranscriptionManager: ObservableObject {
    enum RecordingMode {
        case none
        case pushToTalk
        case handsFree
    }
    
    @Published var isRecording = false
    @Published var isTranscribing = false
    @Published var processingMessage: String = "Transcribing"
    @Published var history: [TranscriptionEntry] = []
    @Published var currentMode: RecordingMode = .none
    @Published var capturedAppIcon: NSImage? = nil
    
    // Persistent binary paths
    @AppStorage("whisperPath") var whisperPath: String = "/opt/homebrew/bin/whisper"
    @AppStorage("ffmpegPath") var ffmpegPath: String = "/opt/homebrew/bin/ffmpeg"
    @AppStorage("copyToClipboardEnabled") var copyToClipboardEnabled: Bool = true

    // Whisper configuration
    @AppStorage("whisperModel") var whisperModel: String = "base"
    @AppStorage("whisperLanguage") var whisperLanguage: String = ""
    @AppStorage("whisperInitialPrompt") var whisperInitialPrompt: String = ""
    
    private var isFnKeyCurrentlyPressed = false
    private var lastFnDownTime: Date = Date.distantPast
    private var pttStopTimer: Timer?
    private var capturedApp: NSRunningApplication?

    private let gemini = GeminiService()
    private let rulesStore = PostProcessingStore.shared
    
    var isAccessibilityTrusted: Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    private let recorder = AudioRecorder()
    private let whisper = WhisperService()
    private var overlayWindow: NSWindow?
    private var eventMonitor: Any?
    
    init() {
        loadHistory()
    }
    
    func toggleRecording() {
        if isRecording {
            stopAndTranscribe()
        } else {
            start()
        }
    }
    
    func cancelRecording() {
        isRecording = false
        _ = recorder.stopRecording()
        hideOverlay()
        NSSound(named: "Basso")?.play()
    }
    
    func getAudioLevel() -> Float {
        return recorder.updateMeters()
    }
    
    private func start() {
        // Capture the frontmost app before we take focus
        capturedApp = NSWorkspace.shared.frontmostApplication
        capturedAppIcon = capturedApp?.icon
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                if granted {
                    NSSound(named: "Basso")?.play()
                    self.isRecording = true
                    self.recorder.startRecording()
                    self.showOverlay()
                } else {
                    print("Microphone access denied.")
                }
            }
        }
    }
    
    private func stopAndTranscribe() {
        NSSound(named: "Pop")?.play()
        isRecording = false
        isTranscribing = true
        processingMessage = "Transcribing"
        
        if let audioURL = recorder.stopRecording() {
            whisper.transcribe(
                audioURL: audioURL,
                whisperPath: whisperPath,
                ffmpegPath: ffmpegPath,
                model: whisperModel,
                language: whisperLanguage,
                initialPrompt: whisperInitialPrompt
            ) { text in
                DispatchQueue.main.async {
                    if let text = text, !text.isEmpty {
                        self.applyPostProcessing(to: text)
                    } else {
                        self.isTranscribing = false
                        self.hideOverlay()
                    }
                }
            }
        } else {
            isTranscribing = false
            hideOverlay()
        }
    }

    private func applyPostProcessing(to text: String) {
        let bundleID = capturedApp?.bundleIdentifier
        let rule = rulesStore.rule(for: bundleID)

        switch rule?.action {
        case .shortcut(let name):
            processingMessage = "Running Shortcut"
            runShortcut(name: name, input: text)
        case .gemini(let prompt):
            let apiKey = rulesStore.geminiAPIKey
            guard !apiKey.isEmpty else {
                print("Gemini API key not configured, inserting raw text.")
                insertText(text, originalText: text, source: nil)
                return
            }
            processingMessage = "Processing with Gemini"
            Task {
                do {
                    let result = try await self.gemini.process(text: text, prompt: prompt, apiKey: apiKey)
                    await MainActor.run { self.insertText(result, originalText: text, source: "Gemini AI") }
                } catch {
                    print("[Gemini] Error: \(error.localizedDescription)")
                    await MainActor.run { self.insertText(text, originalText: text, source: nil) }
                }
            }
        default:
            insertText(text, originalText: text, source: nil)
        }
    }

    private func runShortcut(name: String, input: String) {
        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("whisper_input.txt")
        do {
            try input.write(to: tmpURL, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to write shortcut input: \(error)")
            insertText(input, originalText: input, source: nil)
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["run", name, "--input-path", tmpURL.path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.terminationHandler = { [weak self] _ in
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let plain = Self.plainText(from: data).trimmingCharacters(in: .whitespacesAndNewlines)
            DispatchQueue.main.async {
                if plain.isEmpty {
                    self?.insertText(input, originalText: input, source: nil)
                } else {
                    self?.insertText(plain, originalText: input, source: "Shortcut: \(name)")
                }
            }
            try? FileManager.default.removeItem(at: tmpURL)
        }
        do {
            try process.run()
        } catch {
            print("Failed to run shortcut: \(error)")
            insertText(input, originalText: input, source: nil)
        }
    }

    /// Converts raw Data that may be RTF, RTFD, or plain UTF-8 text into a plain String.
    private static func plainText(from data: Data) -> String {
        // Try RTF first
        if let attributed = try? NSAttributedString(data: data,
                                                    options: [.documentType: NSAttributedString.DocumentType.rtf],
                                                    documentAttributes: nil) {
            return attributed.string
        }
        // Try RTFD
        if let attributed = try? NSAttributedString(data: data,
                                                    options: [.documentType: NSAttributedString.DocumentType.rtfd],
                                                    documentAttributes: nil) {
            return attributed.string
        }
        // Fall back to plain UTF-8
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func showOverlay() {
        if overlayWindow == nil {
            let contentView = RecordingOverlayView(manager: self)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 160, height: 48),
                styleMask: [.borderless, .fullSizeContentView],
                backing: .buffered, defer: false)
            window.isOpaque = false
            window.backgroundColor = .clear
            window.level = .floating
            window.contentView = NSHostingView(rootView: contentView)
            overlayWindow = window
        }
        // Always reposition to the screen containing the mouse cursor
        let mouseLocation = NSEvent.mouseLocation
        let activeScreen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main
        if let screen = activeScreen {
            let x = screen.frame.minX + (screen.frame.width - (overlayWindow?.frame.width ?? 160)) / 2
            let y = screen.frame.minY + screen.frame.height * 0.10
            overlayWindow?.setFrameOrigin(NSPoint(x: x, y: y))
        }
        overlayWindow?.orderFrontRegardless()
    }

    private func hideOverlay() {
        overlayWindow?.orderOut(nil)
    }
    
    private func addToHistory(_ text: String, processedText: String? = nil, processingSource: String? = nil) {
        let entry = TranscriptionEntry(text: text, processedText: processedText, processingSource: processingSource, date: Date())
        history.insert(entry, at: 0)
        saveHistory()
    }
    
    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(encoded, forKey: "transcriptionHistory")
        }
    }
    
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: "transcriptionHistory"),
           let decoded = try? JSONDecoder().decode([TranscriptionEntry].self, from: data) {
            history = decoded
        }
    }
    
    private func insertText(_ text: String, originalText: String, source: String?) {
        let isDifferent = text != originalText
        addToHistory(originalText, processedText: isDifferent ? text : nil, processingSource: source)

        print("Transcription: \(text)")
        NSSound(named: "Glass")?.play()

        // Save the current clipboard contents so we can restore them if the user
        // has opted out of keeping the result on the clipboard.
        let savedItems: [NSPasteboardItem]? = copyToClipboardEnabled ? nil : {
            NSPasteboard.general.pasteboardItems?.map { item in
                let copy = NSPasteboardItem()
                for type in item.types {
                    if let data = item.data(forType: type) {
                        copy.setData(data, forType: type)
                    }
                }
                return copy
            }
        }()

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Activate the original app before pasting so the user can switch away
        // during transcription and the text still lands in the right place.
        self.capturedApp?.activate(options: [])

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let source = CGEventSource(stateID: .combinedSessionState)
            let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
            vDown?.flags = .maskCommand
            let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
            vUp?.flags = .maskCommand

            vDown?.post(tap: .cgAnnotatedSessionEventTap)
            vUp?.post(tap: .cgAnnotatedSessionEventTap)

            self.isTranscribing = false
            self.hideOverlay()

            // Restore clipboard after paste if the user opted out of clipboard copy
            if let saved = savedItems {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    if !saved.isEmpty {
                        pb.writeObjects(saved)
                    }
                }
            }
        }
    }
    
    func setupHotkey() {
        print("Setting up FN key monitor...")
        
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        
        // Check for accessibility permissions
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let isTrusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        print("Accessibility permissions trusted: \(isTrusted)")
        
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self = self else { return }
            
            let isFnDown = event.modifierFlags.contains(.function)
            
            if isFnDown && !self.isFnKeyCurrentlyPressed {
                // Key Down
                self.isFnKeyCurrentlyPressed = true
                self.handleFnDown()
            } else if !isFnDown && self.isFnKeyCurrentlyPressed {
                // Key Up
                self.isFnKeyCurrentlyPressed = false
                self.handleFnUp()
            }
        }
    }
    
    private func handleFnDown() {
        let now = Date()
        let doublePressThreshold: TimeInterval = 0.4 // Slightly more generous for better detection
        
        DispatchQueue.main.async {
            // Cancel any pending PTT stop
            self.pttStopTimer?.invalidate()
            self.pttStopTimer = nil

            if self.isRecording && self.currentMode == .handsFree {
                // Single press to stop hands-free
                print("Stopping hands-free recording...")
                self.stopAndTranscribe()
                self.currentMode = .none
            } else if now.timeIntervalSince(self.lastFnDownTime) < doublePressThreshold {
                // Double press detected!
                print("Double press detected! Switching to hands-free mode.")
                self.currentMode = .handsFree
                if !self.isRecording {
                    self.start()
                }
            } else {
                // Start PTT mode
                print("FN Down: Starting PTT recording...")
                self.currentMode = .pushToTalk
                if !self.isRecording {
                    self.start()
                }
            }
            self.lastFnDownTime = now
        }
    }
    
    private func handleFnUp() {
        DispatchQueue.main.async {
            if self.currentMode == .pushToTalk {
                // Instead of stopping immediately, wait a bit to see if it's a double-press
                print("FN Up: Waiting to see if it's a double-press...")
                self.pttStopTimer?.invalidate()
                self.pttStopTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) { [weak self] _ in
                    guard let self = self else { return }
                    DispatchQueue.main.async {
                        if self.currentMode == .pushToTalk {
                            print("PTT timer expired: Stopping recording...")
                            self.stopAndTranscribe()
                            self.currentMode = .none
                        }
                    }
                }
            }
        }
    }
}
