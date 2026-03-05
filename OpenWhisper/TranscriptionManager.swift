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

    // All active jobs: recording, queued, transcribing, post-processing
    @Published var jobs: [TranscriptionJob] = []
    @Published var history: [TranscriptionEntry] = []
    @Published var currentMode: RecordingMode = .none

    // Computed state used by the menu bar and hotkey logic
    var isRecording: Bool { jobs.contains { $0.state == .recording } }
    var isTranscribing: Bool {
        jobs.contains { job in
            if case .postProcessing = job.state { return true }
            return job.state == .transcribing
        }
    }

    // Persistent binary paths
    @AppStorage("whisperPath") var whisperPath: String = "/opt/homebrew/bin/whisper"
    @AppStorage("ffmpegPath") var ffmpegPath: String = "/opt/homebrew/bin/ffmpeg"
    @AppStorage("copyToClipboardEnabled") var copyToClipboardEnabled: Bool = true

    // Whisper configuration
    @AppStorage("whisperModel") var whisperModel: String = "base"
    @AppStorage("whisperLanguage") var whisperLanguage: String = ""
    @AppStorage("whisperInitialPrompt") var whisperInitialPrompt: String = ""

    // Overlay style: "bubble" (default) or "dynamicIsland"
    @AppStorage("overlayStyle") var overlayStyle: String = "bubble"

    private var isFnKeyCurrentlyPressed = false
    private var lastFnDownTime: Date = Date.distantPast
    private var pttStopTimer: Timer?
    // Ensures only one whisper process runs at a time
    private var isTranscriptionRunning = false

    private let gemini = GeminiService()
    private let rulesStore = PostProcessingStore.shared

    var isAccessibilityTrusted: Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    private let whisper = WhisperService()
    private var overlayWindow: NSWindow?
    private var overlayWindowStyle: String = "" // style the current window was built for
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
        guard let job = jobs.first(where: { $0.state == .recording }) else { return }
        _ = job.recorder.stopRecording()
        removeJob(job)
        NSSound(named: "Basso")?.play()
    }

    func getAudioLevel() -> Float {
        return jobs.first(where: { $0.state == .recording })?.recorder.updateMeters() ?? -160
    }

    // MARK: - Recording

    private func start() {
        let targetApp = NSWorkspace.shared.frontmostApplication
        let job = TranscriptionJob(targetApp: targetApp)

        // Capture the focused AX element's window and PID *before* we take focus.
        // This lets us target the exact browser window / terminal tab and paste
        // in the background without bringing the app to the front.
        let (axWindow, pid) = Self.captureAXTarget()
        job.targetWindow = axWindow
        job.targetPID = pid > 0 ? pid : (targetApp?.processIdentifier ?? 0)

        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                guard granted else {
                    print("Microphone access denied.")
                    return
                }
                NSSound(named: "Basso")?.play()
                job.recorder.startRecording()
                self.objectWillChange.send()
                self.jobs.append(job)
                self.updateOverlay()
            }
        }
    }

    /// Walks the Accessibility tree to find the focused window and its owning PID.
    /// Returns `(nil, 0)` gracefully if accessibility permissions are missing.
    private static func captureAXTarget() -> (window: AXUIElement?, pid: pid_t) {
        let sysWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
                sysWide, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
              let focused = focusedRef else { return (nil, 0) }

        let focusedElement = focused as! AXUIElement

        // PID of the focused element's process
        var pid: pid_t = 0
        AXUIElementGetPid(focusedElement, &pid)

        // Walk up to the enclosing window
        var windowRef: CFTypeRef?
        var window: AXUIElement?
        if AXUIElementCopyAttributeValue(
                focusedElement, kAXWindowAttribute as CFString, &windowRef) == .success,
           let w = windowRef {
            window = (w as! AXUIElement)
        }

        return (window, pid)
    }

    private func stopAndTranscribe() {
        guard let job = jobs.first(where: { $0.state == .recording }) else { return }

        // Discard recordings shorter than 1 second — too brief to be intentional
        guard Date().timeIntervalSince(job.startedAt) >= 1.0 else {
            _ = job.recorder.stopRecording()
            removeJob(job)
            NSSound(named: "Basso")?.play()
            return
        }

        NSSound(named: "Pop")?.play()
        job.audioURL = job.recorder.stopRecording()
        setJobState(job, .queued)
        processNextQueued()
    }

    // MARK: - Queue

    /// Returns (creating if needed) the persistent directory for saved audio recordings.
    private func audioStorageDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("OpenWhisper/Recordings")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Starts transcribing the next queued job if no transcription is already running.
    private func processNextQueued() {
        guard !isTranscriptionRunning,
              let job = jobs.first(where: { $0.state == .queued }) else { return }
        guard let audioURL = job.audioURL else {
            // Audio file missing — drop the job silently
            removeJob(job)
            processNextQueued()
            return
        }

        // Copy the recording to persistent storage BEFORE whisper deletes the temp file.
        let dest = audioStorageDirectory().appendingPathComponent("\(job.id.uuidString).wav")
        try? FileManager.default.copyItem(at: audioURL, to: dest)
        job.savedAudioURL = dest

        isTranscriptionRunning = true
        setJobState(job, .transcribing)

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
                    self.applyPostProcessing(to: text, job: job)
                } else {
                    self.isTranscriptionRunning = false
                    self.removeJob(job)
                    self.processNextQueued()
                }
            }
        }
    }

    // MARK: - Post-processing

    private func applyPostProcessing(to text: String, job: TranscriptionJob) {
        let bundleID = job.targetApp?.bundleIdentifier
        let rule = rulesStore.rule(for: bundleID)

        switch rule?.action {
        case .shortcut(let name):
            setJobState(job, .postProcessing("Running Shortcut"))
            runShortcut(name: name, input: text, job: job)
        case .gemini(let prompt):
            let apiKey = rulesStore.geminiAPIKey
            guard !apiKey.isEmpty else {
                print("Gemini API key not configured, inserting raw text.")
                insertText(text, originalText: text, source: nil, job: job)
                return
            }
            setJobState(job, .postProcessing("Processing with Gemini"))
            Task {
                do {
                    let result = try await self.gemini.process(text: text, prompt: prompt, apiKey: apiKey)
                    await MainActor.run { self.insertText(result, originalText: text, source: "Gemini AI", job: job) }
                } catch {
                    print("[Gemini] Error: \(error.localizedDescription)")
                    await MainActor.run { self.insertText(text, originalText: text, source: nil, job: job) }
                }
            }
        default:
            insertText(text, originalText: text, source: nil, job: job)
        }
    }

    private func runShortcut(name: String, input: String, job: TranscriptionJob) {
        // Use per-job temp file name to avoid collisions between concurrent shortcuts
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("whisper_input_\(job.id.uuidString).txt")
        do {
            try input.write(to: tmpURL, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to write shortcut input: \(error)")
            insertText(input, originalText: input, source: nil, job: job)
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
                    self?.insertText(input, originalText: input, source: nil, job: job)
                } else {
                    self?.insertText(plain, originalText: input, source: "Shortcut: \(name)", job: job)
                }
            }
            try? FileManager.default.removeItem(at: tmpURL)
        }
        do {
            try process.run()
        } catch {
            print("Failed to run shortcut: \(error)")
            insertText(input, originalText: input, source: nil, job: job)
        }
    }

    /// Converts raw Data that may be RTF, RTFD, or plain UTF-8 text into a plain String.
    private static func plainText(from data: Data) -> String {
        if let attributed = try? NSAttributedString(data: data,
                                                    options: [.documentType: NSAttributedString.DocumentType.rtf],
                                                    documentAttributes: nil) {
            return attributed.string
        }
        if let attributed = try? NSAttributedString(data: data,
                                                    options: [.documentType: NSAttributedString.DocumentType.rtfd],
                                                    documentAttributes: nil) {
            return attributed.string
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: - Text insertion

    private func insertText(_ text: String, originalText: String, source: String?, job: TranscriptionJob) {
        let isDifferent = text != originalText
        addToHistory(originalText, processedText: isDifferent ? text : nil, processingSource: source, audioURL: job.savedAudioURL)

        print("Transcription: \(text)")
        NSSound(named: "Glass")?.play()

        let savedItems: [NSPasteboardItem]? = copyToClipboardEnabled ? nil : {
            NSPasteboard.general.pasteboardItems?.map { item in
                let copy = NSPasteboardItem()
                for type in item.types {
                    if let data = item.data(forType: type) { copy.setData(data, forType: type) }
                }
                return copy
            }
        }()

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Activate the target app so it regains keyboard focus, then raise the
        // specific window within it (e.g. the right browser tab / iTerm2 pane).
        job.targetApp?.activate(options: .activateIgnoringOtherApps)
        if let window = job.targetWindow {
            AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        }

        // Wait long enough for the app to become active and restore its focused field.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let source = CGEventSource(stateID: .combinedSessionState)
            let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
            vDown?.flags = .maskCommand
            let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
            vUp?.flags = .maskCommand

            // Post Cmd+V to the session tap so it reaches the now-active app.
            vDown?.post(tap: .cgAnnotatedSessionEventTap)
            vUp?.post(tap: .cgAnnotatedSessionEventTap)

            self.isTranscriptionRunning = false
            self.removeJob(job)
            self.processNextQueued()

            if let saved = savedItems {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    if !saved.isEmpty { pb.writeObjects(saved) }
                }
            }
        }
    }

    // MARK: - Overlay

    private func updateOverlay() {
        guard !jobs.isEmpty else {
            overlayWindow?.orderOut(nil)
            return
        }

        // Recreate the window if the style has changed since it was first built
        if overlayWindowStyle != overlayStyle {
            overlayWindow?.orderOut(nil)
            overlayWindow = nil
        }

        let count = CGFloat(jobs.count)

        if overlayStyle == "dynamicIsland" {
            updateDynamicIslandOverlay(count: count)
        } else if overlayStyle == "dynamicIslandMini" {
            updateDynamicIslandMiniOverlay()
        } else {
            updateBubbleOverlay(count: count)
        }

        overlayWindowStyle = overlayStyle
        overlayWindow?.orderFrontRegardless()
    }

    private func updateBubbleOverlay(count: CGFloat) {
        let rowH: CGFloat = 40
        let divH: CGFloat = 1
        let padH: CGFloat = 16
        let height = count * rowH + max(0, count - 1) * divH + padH
        let width: CGFloat = 185

        if overlayWindow == nil {
            let window = makeOverlayWindow(width: width, height: height, level: .floating)
            overlayWindow = window

            let mouseLocation = NSEvent.mouseLocation
            let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main
            if let screen = screen {
                let x = screen.frame.minX + (screen.frame.width - width) / 2
                let y = screen.frame.minY + screen.frame.height * 0.10
                overlayWindow?.setFrameOrigin(NSPoint(x: x, y: y))
            }
        } else {
            if let origin = overlayWindow?.frame.origin {
                overlayWindow?.setFrame(
                    NSRect(x: origin.x, y: origin.y, width: width, height: height),
                    display: true, animate: true)
            }
        }
    }

    private func updateDynamicIslandOverlay(count: CGFloat) {
        // Each row: 46pt icon + 13*2 vertical padding = 72pt. Dividers = 0.5pt.
        let rowH: CGFloat = 72
        let divH: CGFloat = 1
        let notchClearance: CGFloat = 30  // matches DynamicIslandOverlayView
        let height = count * rowH + max(0, count - 1) * divH + notchClearance
        let width: CGFloat = 320

        // Primary screen (the one with the menu bar / notch) is always screens[0]
        let screen = NSScreen.screens.first ?? NSScreen.main!
        // Center of the screen — the notch is always here
        let screenCenterX = screen.frame.minX + screen.frame.width / 2

        // Final frame: pinned to the very top, expands from center outward
        let targetFrame = NSRect(
            x: screenCenterX - width / 2,
            y: screen.frame.maxY - height,
            width: width,
            height: height
        )

        if overlayWindow == nil {
            let level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
            let window = makeOverlayWindow(width: width, height: height, level: level, style: "dynamicIsland")
            overlayWindow = window

            // Start as a narrow pill the same width as the hardware notch, then
            // expand outward to both sides — the "notch growing" visual.
            let notchW: CGFloat = 130
            let startFrame = NSRect(
                x: screenCenterX - notchW / 2,
                y: screen.frame.maxY - notchClearance,
                width: notchW,
                height: notchClearance
            )
            overlayWindow?.setFrame(startFrame, display: false)
            overlayWindow?.orderFrontRegardless()

            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.45
                ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 0.46, 0.45, 0.94)
                ctx.allowsImplicitAnimation = true
                overlayWindow?.animator().setFrame(targetFrame, display: true)
            }
        } else {
            // Subsequent jobs: expand height downward, keep centered width
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.38
                ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 0.46, 0.45, 0.94)
                ctx.allowsImplicitAnimation = true
                overlayWindow?.animator().setFrame(targetFrame, display: true)
            }
        }
    }

    private func updateDynamicIslandMiniOverlay() {
        // Mini style: fixed height (notch height only), expands left+right — never grows downward
        let height: CGFloat = 32
        let width: CGFloat = 250  // 40 (left) + 162 (notch) + 40 (right) + 4*2 (padding)
        let screen = NSScreen.screens.first ?? NSScreen.main!
        let screenCenterX = screen.frame.minX + screen.frame.width / 2

        let targetFrame = NSRect(
            x: screenCenterX - width / 2,
            y: screen.frame.maxY - height,
            width: width,
            height: height
        )

        if overlayWindow == nil {
            let level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
            let window = makeOverlayWindow(width: width, height: height, level: level, style: "dynamicIslandMini")
            overlayWindow = window

            // Start fully hidden above the screen at notch width, then spring outward+downward
            let notchW: CGFloat = 162
            let startFrame = NSRect(
                x: screenCenterX - notchW / 2,
                y: screen.frame.maxY,          // above screen — hidden inside notch
                width: notchW,
                height: height
            )
            overlayWindow?.alphaValue = 0
            overlayWindow?.setFrame(startFrame, display: false)
            overlayWindow?.orderFrontRegardless()

            // Phase 1: fade in instantly as the spring begins
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.08
                ctx.allowsImplicitAnimation = true
                overlayWindow?.animator().alphaValue = 1
            }

            // Phase 2: spring outward+downward with overshoot (bounce)
            let bounceFrame = NSRect(
                x: targetFrame.minX - 6,
                y: targetFrame.minY - 5,
                width: targetFrame.width + 12,
                height: targetFrame.height
            )
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.38
                ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 0.46, 0.45, 0.94)
                ctx.allowsImplicitAnimation = true
                overlayWindow?.animator().setFrame(bounceFrame, display: true)
            }, completionHandler: {
                // Phase 3: snap back to final size — this is the "bounce"
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.22
                    ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.33, 0.0, 0.66, 1.0)
                    ctx.allowsImplicitAnimation = true
                    self.overlayWindow?.animator().setFrame(targetFrame, display: true)
                }
            })
        }
        // Mini style never resizes on queue changes — the badge conveys the count
    }

    private func makeOverlayWindow(width: CGFloat, height: CGFloat, level: NSWindow.Level, style: String = "bubble") -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = level
        window.hasShadow = (style == "dynamicIsland" || style == "dynamicIslandMini")
        if style == "dynamicIsland" {
            window.contentView = NSHostingView(rootView: DynamicIslandOverlayView(manager: self))
        } else if style == "dynamicIslandMini" {
            window.contentView = NSHostingView(rootView: DynamicIslandMiniOverlayView(manager: self))
        } else {
            window.contentView = NSHostingView(rootView: RecordingOverlayView(manager: self))
        }
        return window
    }

    // MARK: - Helpers

    /// Updates a job's state and notifies the manager's observers so the UI refreshes.
    private func setJobState(_ job: TranscriptionJob, _ state: JobState) {
        objectWillChange.send()
        job.state = state
        updateOverlay()
    }

    private func removeJob(_ job: TranscriptionJob) {
        objectWillChange.send()
        jobs.removeAll { $0.id == job.id }
        updateOverlay()
    }

    private func addToHistory(_ text: String, processedText: String? = nil, processingSource: String? = nil, audioURL: URL? = nil) {
        let entry = TranscriptionEntry(text: text, processedText: processedText, processingSource: processingSource, date: Date(), audioURL: audioURL)
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

    /// Deletes the persistent audio file for a single entry (if any).
    func deleteEntryAudio(_ entry: TranscriptionEntry) {
        if let url = entry.audioURL {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Deletes all persisted audio files for the current history.
    func clearAllAudio() {
        for entry in history { deleteEntryAudio(entry) }
    }

    // MARK: - Hotkey

    func setupHotkey() {
        print("Setting up FN key monitor...")

        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let isTrusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        print("Accessibility permissions trusted: \(isTrusted)")

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self = self else { return }
            let isFnDown = event.modifierFlags.contains(.function)
            if isFnDown && !self.isFnKeyCurrentlyPressed {
                self.isFnKeyCurrentlyPressed = true
                self.handleFnDown()
            } else if !isFnDown && self.isFnKeyCurrentlyPressed {
                self.isFnKeyCurrentlyPressed = false
                self.handleFnUp()
            }
        }
    }

    private func handleFnDown() {
        let now = Date()
        let doublePressThreshold: TimeInterval = 0.4

        DispatchQueue.main.async {
            self.pttStopTimer?.invalidate()
            self.pttStopTimer = nil

            if self.isRecording && self.currentMode == .handsFree {
                print("Stopping hands-free recording...")
                self.stopAndTranscribe()
                self.currentMode = .none
            } else if now.timeIntervalSince(self.lastFnDownTime) < doublePressThreshold {
                print("Double press detected! Switching to hands-free mode.")
                self.currentMode = .handsFree
                if !self.isRecording {
                    self.start()
                }
            } else {
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
