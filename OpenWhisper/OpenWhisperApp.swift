//
//  OpenWhisperApp.swift
//  OpenWhisper
//
//  Created by Jefersson Nathan de Oliveira Chaves on 19/02/2026.
//

import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    let manager = TranscriptionManager()
    var settingsWindow: NSWindow?
    var historyWindow: NSWindow?
    var postProcessingWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        manager.setupHotkey()
    }
    
    @objc func openHistory() {
        if historyWindow == nil {
            let contentView = HistoryView(manager: manager)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 450, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered, defer: false)
            window.title = "Transcription History"
            window.contentView = NSHostingView(rootView: contentView)
            window.center()
            window.isReleasedWhenClosed = false
            historyWindow = window
        }
        historyWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func openSettings() {
        if settingsWindow == nil {
            let contentView = SettingsView(manager: manager)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 350, height: 250),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered, defer: false)
            window.title = "OpenWhisper Settings"
            window.contentView = NSHostingView(rootView: contentView)
            window.center()
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func openPostProcessing() {
        if postProcessingWindow == nil {
            let contentView = PostProcessingSettingsView()
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 520),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered, defer: false)
            window.title = "Post-Processing Rules"
            window.contentView = NSHostingView(rootView: contentView)
            window.center()
            window.isReleasedWhenClosed = false
            postProcessingWindow = window
        }
        postProcessingWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct OpenWhisperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        MenuBarExtra {
            if appDelegate.manager.isRecording {
                Text("🔴 Recording...")
                Text("Press Stop to transcribe")
                    .font(.caption)
            } else if appDelegate.manager.isTranscribing {
                Text("⌛ Transcribing...")
            } else {
                Text("Ready")
            }
            
            Divider()
            
            Button(appDelegate.manager.isRecording ? "Stop Recording" : "Start Recording") {
                appDelegate.manager.toggleRecording()
            }
            .keyboardShortcut("r")
            
            Button("History...") {
                appDelegate.openHistory()
            }
            .keyboardShortcut("h")
            
            Button("Settings...") {
                appDelegate.openSettings()
            }
            .keyboardShortcut(",")

            Button("Post-Processing...") {
                appDelegate.openPostProcessing()
            }
            .keyboardShortcut("p")
            
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
