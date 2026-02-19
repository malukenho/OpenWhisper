//
//  OpenWhisperApp.swift
//  OpenWhisper
//
//  Created by Jefersson Nathan de Oliveira Chaves on 19/02/2026.
//

import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    let manager = TranscriptionManager()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        manager.setupHotkey()
    }
}

@main
struct OpenWhisperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        MenuBarExtra {
            if appDelegate.manager.isRecording {
                Text("🔴 Recording...")
                Text("Press Cmd+Shift+L to stop")
                    .font(.caption)
            } else if appDelegate.manager.isTranscribing {
                Text("⌛ Transcribing...")
            } else {
                Text("Ready")
                Text("Hotkey: Cmd+Shift+L")
                    .font(.caption)
            }
            
            Divider()
            
            Button(appDelegate.manager.isRecording ? "Stop Recording" : "Start Recording") {
                appDelegate.manager.toggleRecording()
            }
            .keyboardShortcut("r")
            
            Divider()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        } label: {
            if appDelegate.manager.isRecording {
                Image(systemName: "mic.fill")
                    .foregroundColor(.red)
            } else if appDelegate.manager.isTranscribing {
                Image(systemName: "waveform.circle.fill")
            } else {
                Image(systemName: "waveform.circle")
            }
        }
    }
}
