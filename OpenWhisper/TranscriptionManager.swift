import Foundation
import SwiftUI
import AppKit
import Combine
import AVFoundation

class TranscriptionManager: ObservableObject {
    @Published var isRecording = false
    @Published var isTranscribing = false
    
    private let recorder = AudioRecorder()
    private let whisper = WhisperService()
    private var overlayWindow: NSWindow?
    
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
                    // Optional: Show an alert or notification
                }
            }
        }
    }
    
    private func stopAndTranscribe() {
        NSSound(named: "Pop")?.play()
        isRecording = false
        isTranscribing = true
        hideOverlay()
        
        if let audioURL = recorder.stopRecording() {
            whisper.transcribe(audioURL: audioURL) { text in
                DispatchQueue.main.async {
                    self.isTranscribing = false
                    if let text = text, !text.isEmpty {
                        self.insertText(text)
                    }
                }
            }
        } else {
            isTranscribing = false
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
            // Position slightly above the bottom of the screen
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
        // 1. Copy to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        print("Transcription: \(text)")
        
        // 2. Play success sound
        NSSound(named: "Glass")?.play()
        
        // 3. Insert at cursor via Cmd+V simulation
        // We add a tiny delay to ensure focus is returned to the original app 
        // after the overlay window is hidden.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let source = CGEventSource(stateID: .combinedSessionState)
            
            // Virtual key code for 'v' is 9
            let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
            vDown?.flags = .maskCommand
            
            let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
            vUp?.flags = .maskCommand
            
            vDown?.post(tap: .cgAnnotatedSessionEventTap)
            vUp?.post(tap: .cgAnnotatedSessionEventTap)
        }
    }
    
    func setupHotkey() {
        // We use a global monitor for a specific key combo
        // For example: Cmd+Shift+L
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            // cmd: 0x100000, shift: 0x20000, l: 37
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 37 {
                DispatchQueue.main.async {
                    self.toggleRecording()
                }
            }
        }
    }
}
