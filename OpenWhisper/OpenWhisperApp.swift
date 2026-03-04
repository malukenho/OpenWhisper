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
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 580),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered, defer: false)
            window.title = "OpenWhisper Settings"
            window.titlebarAppearsTransparent = true
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
            let jobs = appDelegate.manager.jobs
            let recording = jobs.filter { $0.state == .recording }
            let queued = jobs.filter { $0.state == .queued }
            let processing = jobs.filter { job in
                if case .postProcessing = job.state { return true }
                return job.state == .transcribing
            }

            if !recording.isEmpty {
                Text("🔴 Recording…")
                if !queued.isEmpty || !processing.isEmpty {
                    Text("\(queued.count + processing.count) job(s) in queue")
                        .font(.caption)
                }
            } else if !processing.isEmpty || !queued.isEmpty {
                Text("⌛ Processing… (\(jobs.count) job(s))")
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
                    .symbolRenderingMode(.hierarchical)
            } else if !appDelegate.manager.jobs.isEmpty {
                Image(systemName: "ellipsis.bubble.fill")
                    .symbolRenderingMode(.hierarchical)
            } else {
                Image(systemName: "bubble.left.fill")
                    .symbolRenderingMode(.monochrome)
            }
        }
    }
}
