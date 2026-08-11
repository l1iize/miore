import Foundation

enum AppSection: String, CaseIterable, Identifiable {
    case home, instances, content, console, assistant, settings
    var id: String { rawValue }
    var title: String {
        switch self {
        case .home: return L10n.t("nav.home")
        case .instances: return L10n.t("nav.instances")
        case .content: return L10n.t("nav.content")
        case .console: return L10n.t("nav.console")
        case .assistant: return L10n.t("nav.assistant")
        case .settings: return L10n.t("nav.settings")
        }
    }
    var symbol: String {
        switch self {
        case .home: return "house"
        case .instances: return "square.stack.3d.up"
        case .content: return "shippingbox"
        case .console: return "terminal"
        case .assistant: return "sparkles"
        case .settings: return "gearshape"
        }
    }
}

enum LoaderKind: String, Codable, CaseIterable {
    case vanilla = "VANILLA"
    case fabric = "FABRIC"
    case forge = "FORGE"
    case neoForge = "NEOFORGE"
    case quilt = "QUILT"
    case modpack = "MODPACK"

    static func detect(versionID: String, json: [String: Any]) -> LoaderKind {
        let text = (versionID + " " + String(describing: json)).lowercased()
        if text.contains("neoforge") { return .neoForge }
        if text.contains("fabric") { return .fabric }
        if text.contains("quilt") { return .quilt }
        if text.contains("forge") { return .forge }
        return .vanilla
    }

    var subtitle: String {
        switch self {
        case .vanilla: return L10n.t("loader.vanilla")
        case .fabric: return "Fabric"
        case .forge: return "Forge"
        case .neoForge: return "NeoForge"
        case .quilt: return "Quilt"
        case .modpack: return "Modpack"
        }
    }
}

struct GameInstance: Identifiable, Hashable {
    let id: String
    let name: String
    let versionDirectory: URL
    let gameVersion: String
    let loader: LoaderKind
    let modifiedAt: Date
}

enum NativeClassifier {
    static var currentArchitecture: String {
        #if arch(arm64)
        return "arm64"
        #else
        return "x86_64"
        #endif
    }

    static func candidates(template: String, architecture: String = currentArchitecture) -> [String] {
        let substitutions = [architecture, "arm64", "x86_64", "64"]
        var values = substitutions.map { template.replacingOccurrences(of: "${arch}", with: $0) }
        if template.contains("${arch}") {
            values.append(template.replacingOccurrences(of: "-${arch}", with: ""))
        }
        var seen = Set<String>()
        return values.filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}

enum LaunchState: Equatable {
    case idle
    case preparing
    case running(pid: Int32)
    case failed(String)

    var isActive: Bool {
        switch self {
        case .preparing, .running: return true
        case .idle, .failed: return false
        }
    }

    var label: String {
        switch self {
        case .idle: return L10n.t("state.idle")
        case .preparing: return L10n.t("state.preparing")
        case .running: return L10n.t("state.running")
        case .failed: return L10n.t("state.failed")
        }
    }
}

struct ChatMessage: Identifiable, Equatable {
    enum Role { case user, assistant, system }
    let id = UUID()
    let role: Role
    let text: String
    let date: Date
}

enum AIProvider: String, CaseIterable, Identifiable {
    case openAI = "OpenAI"
    case deepSeek = "DeepSeek"
    case anthropic = "Anthropic"
    case openRouter = "OpenRouter"
    case ollama = "Ollama"
    case custom = "Custom (OpenAI-compatible)"
    var id: String { rawValue }
    var displayName: String { self == .custom ? L10n.t("ai.custom") : rawValue }

    var defaultEndpoint: String {
        switch self {
        case .openAI: return "https://api.openai.com/v1/chat/completions"
        case .deepSeek: return "https://api.deepseek.com/v1/chat/completions"
        case .anthropic: return "https://api.anthropic.com/v1/messages"
        case .openRouter: return "https://openrouter.ai/api/v1/chat/completions"
        case .ollama: return "http://127.0.0.1:11434/v1/chat/completions"
        case .custom: return ""
        }
    }

    var defaultModel: String {
        switch self {
        case .openAI: return "gpt-4o-mini"
        case .deepSeek: return "deepseek-chat"
        case .anthropic: return "claude-3-5-sonnet-latest"
        case .openRouter: return "openai/gpt-4o-mini"
        case .ollama: return "llama3.2"
        case .custom: return ""
        }
    }

    func completedEndpoint(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        guard var components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(), ["http", "https"].contains(scheme),
              components.host != nil else { return trimmed }

        let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard path.isEmpty || path == "v1" else { return trimmed }
        components.path = self == .anthropic ? "/v1/messages" : "/v1/chat/completions"
        return components.string ?? trimmed
    }
}
