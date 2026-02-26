import SwiftUI
import AppKit

// MARK: - Main Post-Processing Settings View

struct PostProcessingSettingsView: View {
    @ObservedObject var store = PostProcessingStore.shared
    @State private var showingAddRule = false
    @State private var editingRule: PostProcessingRule? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Post-Processing")
                    .font(.headline)
                Text("Transform transcriptions before inserting — per app.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()

            Divider()

            // Gemini API Key
            VStack(alignment: .leading, spacing: 6) {
                Label("Gemini API Key", systemImage: "key.fill")
                    .font(.subheadline).fontWeight(.bold)
                SecureField("Paste your Gemini API key…", text: $store.geminiAPIKey)
                    .textFieldStyle(.roundedBorder)
                Link("Get a free key at aistudio.google.com", destination: URL(string: "https://aistudio.google.com/app/apikey")!)
                    .font(.caption)
            }
            .padding()
            .background(Color.secondary.opacity(0.08))

            Divider()

            // Rules list
            if store.rules.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No rules yet")
                        .foregroundColor(.secondary)
                    Text("Add rules to transform transcriptions differently per app.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List {
                    ForEach(store.rules) { rule in
                        RuleRowView(rule: rule, onToggleEnabled: {
                            if let idx = store.rules.firstIndex(where: { $0.id == rule.id }) {
                                store.rules[idx].isEnabled.toggle()
                            }
                        })
                            .contentShape(Rectangle())
                            .onTapGesture { editingRule = rule }
                    }
                    .onDelete { offsets in
                        store.rules.remove(atOffsets: offsets)
                    }
                }
                .listStyle(.inset)
            }

            Divider()

            // Toolbar
            HStack {
                Button {
                    showingAddRule = true
                } label: {
                    Label("Add Rule", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)

                Spacer()

                Text("\(store.rules.count) rule\(store.rules.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .frame(width: 480, height: 520)
        .sheet(isPresented: $showingAddRule) {
            RuleEditorView(existingRule: nil) { newRule in
                store.rules.append(newRule)
            }
        }
        .sheet(item: $editingRule) { rule in
            RuleEditorView(existingRule: rule, onSave: { updated in
                if let idx = store.rules.firstIndex(where: { $0.id == updated.id }) {
                    store.rules[idx] = updated
                }
            }, onDelete: {
                store.rules.removeAll { $0.id == rule.id }
            })
        }
    }
}

// MARK: - Rule Row

struct RuleRowView: View {
    let rule: PostProcessingRule
    var onToggleEnabled: () -> Void = {}

    var appIcon: NSImage? {
        guard rule.appBundleID != PostProcessingRule.defaultBundleID,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: rule.appBundleID)
        else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    var body: some View {
        HStack(spacing: 12) {
            if let icon = appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 28, height: 28)
            } else {
                Image(systemName: rule.appBundleID == PostProcessingRule.defaultBundleID ? "star.fill" : "app.dashed")
                    .font(.title2)
                    .frame(width: 28, height: 28)
                    .foregroundColor(rule.appBundleID == PostProcessingRule.defaultBundleID ? .yellow : .secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(rule.appName)
                    .fontWeight(.medium)
                    .foregroundColor(rule.isEnabled ? .primary : .secondary)
                Text(rule.action.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: Binding(get: { rule.isEnabled }, set: { _ in onToggleEnabled() }))
                .labelsHidden()
                .onTapGesture { onToggleEnabled() }

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Rule Editor

struct RuleEditorView: View {
    @Environment(\.dismiss) var dismiss

    let existingRule: PostProcessingRule?
    let onSave: (PostProcessingRule) -> Void
    var onDelete: (() -> Void)? = nil

    @State private var appBundleID: String
    @State private var appName: String
    @State private var actionType: String   // "passThrough", "shortcut", "gemini"
    @State private var shortcutName: String
    @State private var geminiPrompt: String
    @State private var runningApps: [NSRunningApplication] = []

    init(existingRule: PostProcessingRule?, onSave: @escaping (PostProcessingRule) -> Void, onDelete: (() -> Void)? = nil) {
        self.existingRule = existingRule
        self.onSave = onSave
        self.onDelete = onDelete

        let rule = existingRule
        _appBundleID = State(initialValue: rule?.appBundleID ?? "")
        _appName = State(initialValue: rule?.appName ?? "")
        _shortcutName = State(initialValue: {
            if case .shortcut(let n) = rule?.action { return n }
            return ""
        }())
        _geminiPrompt = State(initialValue: {
            if case .gemini(let p) = rule?.action { return p }
            return ""
        }())
        _actionType = State(initialValue: {
            switch rule?.action {
            case .shortcut: return "shortcut"
            case .gemini: return "gemini"
            default: return "passThrough"
            }
        }())
    }

    var isDefault: Bool { appBundleID == PostProcessingRule.defaultBundleID }

    var body: some View {
        VStack(spacing: 0) {
            Text(existingRule == nil ? "Add Rule" : "Edit Rule")
                .font(.headline)
                .padding()

            Divider()

            Form {
                // App picker
                Section("Target App") {
                    if !isDefault {
                        Picker("App", selection: $appBundleID) {
                            Text("Choose…").tag("")
                            ForEach(runningApps, id: \.bundleIdentifier) { app in
                                HStack {
                                    if let icon = app.icon {
                                        Image(nsImage: icon).resizable().frame(width: 16, height: 16)
                                    }
                                    Text(app.localizedName ?? app.bundleIdentifier ?? "Unknown")
                                }
                                .tag(app.bundleIdentifier ?? "")
                            }
                        }
                        .onChange(of: appBundleID) { id in
                            if let app = runningApps.first(where: { $0.bundleIdentifier == id }) {
                                appName = app.localizedName ?? id
                            }
                        }

                        TextField("…or enter Bundle ID manually", text: $appBundleID)
                            .font(.caption)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        Label("Default rule (applies to all unmatched apps)", systemImage: "star.fill")
                            .foregroundColor(.secondary)
                    }

                    Toggle("Use as default rule", isOn: Binding(
                        get: { appBundleID == PostProcessingRule.defaultBundleID },
                        set: { val in
                            if val {
                                appBundleID = PostProcessingRule.defaultBundleID
                                appName = "Default"
                            } else {
                                appBundleID = ""
                                appName = ""
                            }
                        }
                    ))
                }

                // Action picker
                Section("Action") {
                    Picker("Action", selection: $actionType) {
                        Text("Insert as-is").tag("passThrough")
                        Text("macOS Shortcut").tag("shortcut")
                        Text("Gemini AI").tag("gemini")
                    }
                    .pickerStyle(.segmented)

                    if actionType == "shortcut" {
                        TextField("Shortcut name", text: $shortcutName)
                            .textFieldStyle(.roundedBorder)
                        Text("The shortcut will receive the transcription as text input and its output will be pasted.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if actionType == "gemini" {
                        Text("System prompt (the transcription will be appended):")
                            .font(.caption)
                        TextEditor(text: $geminiPrompt)
                            .frame(height: 100)
                            .font(.body)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
                        Text("Example: \"Fix grammar and punctuation in the following text:\"")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                if let onDelete = onDelete {
                    Spacer()
                    Button(role: .destructive) {
                        onDelete()
                        dismiss()
                    } label: {
                        Label("Delete Rule", systemImage: "trash")
                    }
                }
                Spacer()
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(appBundleID.isEmpty || (actionType == "shortcut" && shortcutName.isEmpty))
            }
            .padding()
        }
        .frame(width: 440, height: 460)
        .onAppear {
            runningApps = NSWorkspace.shared.runningApplications
                .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil }
                .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
        }
    }

    private func save() {
        let action: ActionType
        switch actionType {
        case "shortcut": action = .shortcut(name: shortcutName)
        case "gemini":   action = .gemini(prompt: geminiPrompt)
        default:         action = .passThrough
        }

        let displayName: String
        if appBundleID == PostProcessingRule.defaultBundleID {
            displayName = "Default"
        } else if !appName.isEmpty {
            displayName = appName
        } else {
            displayName = appBundleID
        }

        let rule = PostProcessingRule(
            id: existingRule?.id ?? UUID(),
            appBundleID: appBundleID,
            appName: displayName,
            action: action
        )
        onSave(rule)
        dismiss()
    }
}
