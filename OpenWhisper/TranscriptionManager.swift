import Foundation
import SwiftUI
import AppKit
import Combine
import AVFoundation

class TranscriptionManager: ObservableObject {
    @Published var isRecording = false
    @Published var isTranscribing = false
    
    // Persistent shortcut settings
    @AppStorage("shortcutKeyCode") var shortcutKeyCode: Int = 37 // Default 'L'
    @AppStorage("shortcutModifiers") var shortcutModifiers: Int = 1179648 // Default Cmd+Shift
    
    // Persistent binary paths
    @AppStorage("whisperPath") var whisperPath: String = "/opt/homebrew/bin/whisper"
    @AppStorage("binPath") var binPath: String = "/opt/homebrew/bin"
    
    var isAccessibilityTrusted: Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    private let recorder = AudioRecorder()
    private let whisper = WhisperService()
    private var overlayWindow: NSWindow?
    private var eventMonitor: Any?
    
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
                contentRect: NSRect(x: 0, y: 0, width: 200, height: 60),
                styleMask: [.borderless, .fullSizeContentView],
                backing: .buffered, defer: false)
            window.isOpaque = false
            window.backgroundColor = .clear
            window.level = .floating
            window.contentView = NSHostingView(rootView: contentView)
            window.center()
            if let screen = NSScreen.main {
                let x = (screen.frame.width - window.frame.width) / 2
                let y = screen.frame.height * 0.15
                window.setFrameOrigin(NSPoint(x: x, y: y))
            }
            overlayWindow = window
        }
        overlayWindow?.orderFrontRegardless()
    }

    private func hideOverlay() {
        overlayWindow?.orderOut(nil)
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
        print("Setting up hotkey: \(shortcutKeyCode) with modifiers \(shortcutModifiers)")
        
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        
        // Check for accessibility permissions
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let isTrusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        print("Accessibility permissions trusted: \(isTrusted)")
        
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return }
            
            let currentModifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue
            
            // Debug: print(String(format: "Key: %d, Mod: 0x%08X", event.keyCode, currentModifiers))
            
            if Int(currentModifiers) == self.shortcutModifiers && Int(event.keyCode) == self.shortcutKeyCode {
                print("Hotkey triggered!")
                DispatchQueue.main.async {
                    self.toggleRecording()
                }
            }
        }
    }
}
