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
    @Published var history: [TranscriptionEntry] = []
    @Published var currentMode: RecordingMode = .none
    
    // Persistent binary paths
    @AppStorage("whisperPath") var whisperPath: String = "/opt/homebrew/bin/whisper"
    @AppStorage("binPath") var binPath: String = "/opt/homebrew/bin"
    
    private var isFnKeyCurrentlyPressed = false
    private var lastFnDownTime: Date = Date.distantPast
    private var pttStopTimer: Timer?
    
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
        
        if let audioURL = recorder.stopRecording() {
            whisper.transcribe(audioURL: audioURL, whisperPath: whisperPath, binPath: binPath) { text in
                DispatchQueue.main.async {
                    if let text = text, !text.isEmpty {
                        self.addToHistory(text)
                        self.insertText(text)
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
            window.center()
            if let screen = NSScreen.main {
                let x = (screen.frame.width - window.frame.width) / 2
                let y = screen.frame.height * 0.10 // Moved from 0.15 to 0.10
                window.setFrameOrigin(NSPoint(x: x, y: y))
            }
            overlayWindow = window
        }
        overlayWindow?.orderFrontRegardless()
    }

    private func hideOverlay() {
        overlayWindow?.orderOut(nil)
    }
    
    private func addToHistory(_ text: String) {
        let entry = TranscriptionEntry(text: text, date: Date())
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
    
    private func insertText(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        print("Transcription: \(text)")
        NSSound(named: "Glass")?.play()
        
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
