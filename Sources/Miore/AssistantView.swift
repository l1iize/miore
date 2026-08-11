import SwiftUI

struct AssistantView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var ai: AIService
    @State private var input = ""

    init(model: AppModel) { self.model = model; self.ai = model.ai }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .bottom) {
                SectionTitle(kicker: "AI", title: L10n.t("assistant.title"), detail: L10n.t("assistant.detail"))
                Spacer()
                if !ai.messages.isEmpty { Button(L10n.t("assistant.clear")) { ai.clear() }.buttonStyle(GhostButtonStyle()) }
            }
            Hairline()
        if !ai.isConfigured { unconfigured } else { conversation }
        }
        .padding(32).frame(maxWidth: 980, maxHeight: .infinity).frame(maxWidth: .infinity)
    }

    private var unconfigured: some View {
        VStack(spacing: 15) {
            Image(systemName: "key.horizontal").font(.system(size: 28, weight: .thin)).foregroundColor(MioreTheme.muted)
            Text(L10n.t("assistant.unconfigured")).font(.miore(size: 15, weight: .medium))
            Text(L10n.t("assistant.keychain"))
                .font(.miore(size: 12)).foregroundColor(MioreTheme.muted)
            Button(L10n.t("assistant.open_settings")) { model.section = .settings }.buttonStyle(PrimaryButtonStyle(compact: true))
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var conversation: some View {
        VStack(spacing: 12) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        if ai.messages.isEmpty {
                            VStack(spacing: 10) {
                                Text(L10n.t("assistant.empty")).font(.miore(size: 13)).foregroundColor(MioreTheme.muted)
                            }.frame(maxWidth: .infinity).padding(.top, 80)
                        }
                        ForEach(ai.messages) { message in MessageRow(message: message).id(message.id) }
                        if ai.isLoading {
                            HStack(spacing: 8) { ProgressView().controlSize(.small); Text(L10n.t("assistant.working")) }
                                .font(.miore(size: 11)).foregroundColor(MioreTheme.muted)
                        }
                        if let error = ai.lastError {
                            Text(error).font(.miore(size: 11, design: .monospaced)).foregroundColor(MioreTheme.foreground).padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading).overlay(Rectangle().stroke(MioreTheme.foreground.opacity(0.35), lineWidth: 1))
                        }
                        Color.clear.frame(height: 1).id("END")
                    }.padding(18)
                }
                .background(MioreTheme.field).overlay(Rectangle().stroke(MioreTheme.border, lineWidth: 1))
                .onChange(of: ai.messages) { _ in proxy.scrollTo("END", anchor: .bottom) }
            }
            HStack(spacing: 10) {
                TextField(L10n.t("assistant.empty"), text: $input)
                    .mioreTextField().onSubmit(send)
                Button(L10n.t("assistant.send"), action: send).buttonStyle(PrimaryButtonStyle(compact: true)).disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || ai.isLoading)
            }
            Text(L10n.t("assistant.privacy"))
                .font(.miore(size: 9)).foregroundColor(MioreTheme.subtle).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func send() {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        input = ""
        ai.send(value)
    }
}

private struct MessageRow: View {
    let message: ChatMessage
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(message.role == .assistant ? "Mio" : L10n.t("assistant.you"))
                .font(.miore(size: 10, weight: .semibold, design: .monospaced)).frame(width: 26, alignment: .leading).foregroundColor(MioreTheme.muted)
            Text(message.text).font(.miore(size: 12)).textSelection(.enabled).lineSpacing(4).frame(maxWidth: 660, alignment: .leading)
            Spacer(minLength: 0)
        }
    }
}
