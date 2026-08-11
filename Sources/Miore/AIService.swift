import Foundation

final class AIService: ObservableObject {
    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var isLoading = false
    @Published var lastError: String?
    private var activeTask: URLSessionDataTask?
    private var requestGeneration = 0

    private let settings: SettingsStore
    private let soul = MioAssistantSoul.prompt
    private var accountNameProvider: () -> String = { "Player" }

    init(settings: SettingsStore) { self.settings = settings }

    func setAccountNameProvider(_ provider: @escaping () -> String) {
        accountNameProvider = provider
    }

    var isConfigured: Bool {
        !settings.endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !settings.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (settings.provider == .ollama || !settings.apiKey.isEmpty)
    }

    func greet(instanceCount: Int) {
        guard settings.aiGreeting, isConfigured, messages.isEmpty else { return }
        send("Miore has just opened. The launcher found \(instanceCount) installed Minecraft instance(s). Greet the user by the supplied current account display name. Write exactly one short, warm greeting in \(settings.appLanguage.promptName). Do not use a pet name or family-role term. Do not mention troubleshooting, diagnostics, errors, logs, support, or your capabilities.", visibleToUser: false)
    }

    func diagnose(log: String) {
        let sanitized = Self.sanitize(String(log.suffix(80_000)))
        send("Diagnose the Minecraft launch log below. Reply in \(settings.appLanguage.promptName). Lead with the conclusion, cite only the key error, then give ordered repair steps.\n\n```log\n\(sanitized)\n```", visibleToUser: true, visibleText: L10n.t("console.diagnose"))
    }

    func send(_ text: String, visibleToUser: Bool = true, visibleText: String? = nil) {
        guard !isLoading else {
            lastError = L10n.t("assistant.busy")
            return
        }
        guard isConfigured else {
            lastError = L10n.t("assistant.unconfigured")
            return
        }
        if visibleToUser { messages.append(ChatMessage(role: .user, text: visibleText ?? text, date: Date())) }
        isLoading = true
        lastError = nil
        requestGeneration += 1
        let generation = requestGeneration

        do {
            let request = try buildRequest(latest: text, excludingLastVisibleMessage: visibleToUser)
            activeTask = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                DispatchQueue.main.async {
                    guard let self, generation == self.requestGeneration else { return }
                    self.isLoading = false
                    if let error { self.lastError = error.localizedDescription; return }
                    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), let data else {
                        let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? "No response"
                        self.lastError = "AI request failed: \(body.prefix(600))"
                        return
                    }
                    guard let answer = self.parseResponse(data) else {
                        self.lastError = "Mio could not understand the AI response."
                        return
                    }
                    self.messages.append(ChatMessage(role: .assistant, text: answer, date: Date()))
                }
            }
            activeTask?.resume()
        } catch {
            isLoading = false
            lastError = error.localizedDescription
        }
    }

    func clear() {
        requestGeneration += 1
        activeTask?.cancel(); activeTask = nil
        isLoading = false
        messages.removeAll(); lastError = nil
    }

    func languageDidChange(instanceCount: Int) {
        requestGeneration += 1
        activeTask?.cancel(); activeTask = nil
        isLoading = false; lastError = nil; messages.removeAll()
        greet(instanceCount: instanceCount)
    }

    private func buildRequest(latest: String, excludingLastVisibleMessage: Bool) throws -> URLRequest {
        guard let url = URL(string: settings.endpoint) else { throw URLError(.badURL) }
        var request = URLRequest(url: url, timeoutInterval: 120)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let historySource = excludingLastVisibleMessage ? messages.dropLast() : messages[...]
        let history = historySource.suffix(12).map { message -> [String: String] in
            ["role": message.role == .assistant ? "assistant" : "user", "content": message.text]
        }
        if settings.provider == .anthropic {
            request.setValue(settings.apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            let localizedSoul = contextualSoul
            let body: [String: Any] = ["model": settings.model, "max_tokens": 1200, "system": localizedSoul,
                                       "messages": history + [["role": "user", "content": latest]]]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } else {
            if !settings.apiKey.isEmpty { request.setValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization") }
            let localizedSoul = contextualSoul
            let body: [String: Any] = ["model": settings.model, "temperature": 0.4,
                                       "messages": [["role": "system", "content": localizedSoul]] + history + [["role": "user", "content": latest]]]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        return request
    }

    private var contextualSoul: String {
        let rawName = accountNameProvider().trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = rawName.isEmpty ? "Player" : String(rawName.prefix(64))
        return soul + "\n\nCurrent UI language: \(settings.appLanguage.promptName).\nCurrent user account display name: \(displayName). Address the user with this name when a direct form of address is useful."
    }

    private func parseResponse(_ data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if settings.provider == .anthropic,
           let content = json["content"] as? [[String: Any]],
           let text = content.first(where: { ($0["type"] as? String) == "text" })?["text"] as? String { return text }
        if let choices = json["choices"] as? [[String: Any]],
           let message = choices.first?["message"] as? [String: Any], let text = message["content"] as? String { return text }
        return nil
    }

    static func sanitize(_ value: String) -> String {
        var result = value
        let patterns = [
            #"(?i)(api[_ -]?key|authorization|access[_ -]?token|password)(\s*[:=]\s*)([^\s,;]+)"#,
            #"Bearer\s+[A-Za-z0-9._~+/=-]+"#,
            NSRegularExpression.escapedPattern(for: NSHomeDirectory())
        ]
        let replacements = ["$1$2<redacted>", "Bearer <redacted>", "~"]
        for (index, pattern) in patterns.enumerated() {
            result = result.replacingOccurrences(of: pattern, with: replacements[index], options: [.regularExpression, .caseInsensitive])
        }
        return result
    }
}
