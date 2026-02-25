import Foundation
import AppKit
import Combine

// MARK: - Action Type

enum ActionType: Codable, Equatable {
    case passThrough
    case shortcut(name: String)
    case gemini(prompt: String)

    enum CodingKeys: String, CodingKey {
        case type, name, prompt
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .passThrough:
            try container.encode("passThrough", forKey: .type)
        case .shortcut(let name):
            try container.encode("shortcut", forKey: .type)
            try container.encode(name, forKey: .name)
        case .gemini(let prompt):
            try container.encode("gemini", forKey: .type)
            try container.encode(prompt, forKey: .prompt)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type_ = try container.decode(String.self, forKey: .type)
        switch type_ {
        case "shortcut":
            let name = try container.decode(String.self, forKey: .name)
            self = .shortcut(name: name)
        case "gemini":
            let prompt = try container.decode(String.self, forKey: .prompt)
            self = .gemini(prompt: prompt)
        default:
            self = .passThrough
        }
    }

    var displayName: String {
        switch self {
        case .passThrough: return "Insert as-is"
        case .shortcut(let name): return "Shortcut: \(name)"
        case .gemini: return "Gemini AI"
        }
    }
}

// MARK: - Rule

struct PostProcessingRule: Codable, Identifiable {
    var id: UUID = UUID()
    /// Bundle identifier of the target app. Use "*" for the default/catch-all rule.
    var appBundleID: String
    var appName: String
    var action: ActionType

    static let defaultBundleID = "*"
}

// MARK: - Rules Store

class PostProcessingStore: ObservableObject {
    static let shared = PostProcessingStore()

    @Published var rules: [PostProcessingRule] = [] {
        didSet { save() }
    }

    @Published var geminiAPIKey: String = "" {
        didSet { UserDefaults.standard.set(geminiAPIKey, forKey: "geminiAPIKey") }
    }

    private let rulesKey = "postProcessingRules"

    init() {
        load()
        geminiAPIKey = UserDefaults.standard.string(forKey: "geminiAPIKey") ?? ""
    }

    // MARK: - Persistence

    private func save() {
        if let encoded = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(encoded, forKey: rulesKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: rulesKey),
           let decoded = try? JSONDecoder().decode([PostProcessingRule].self, from: data) {
            rules = decoded
        }
    }

    // MARK: - Lookup

    /// Returns the best matching rule for a given bundle ID.
    func rule(for bundleID: String?) -> PostProcessingRule? {
        guard let bundleID = bundleID else {
            return rules.first { $0.appBundleID == PostProcessingRule.defaultBundleID }
        }
        return rules.first { $0.appBundleID == bundleID }
            ?? rules.first { $0.appBundleID == PostProcessingRule.defaultBundleID }
    }
}
