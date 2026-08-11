import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var settings: SettingsStore
    @ObservedObject private var account: MicrosoftAccountService
    @ObservedObject private var javaRuntimes: JavaRuntimeService
    @State private var apiKey = ""
    @State private var endpointDraft = ""
    @State private var savedKey = false
    @State private var savedEndpoint = false
    @FocusState private var endpointFocused: Bool

    init(model: AppModel) {
        self.model = model
        self.settings = model.settings
        self.account = model.account
        self.javaRuntimes = model.javaRuntimes
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                HStack(alignment: .bottom) {
                    SectionTitle(kicker: "Preferences", title: L10n.t("settings.title"), detail: L10n.t("settings.detail"))
                    Spacer()
                    Picker(L10n.t("settings.language"), selection: Binding(get: { settings.appLanguage }, set: { model.changeLanguage($0) })) {
                        ForEach(AppLanguage.allCases) { Text($0.displayName).tag($0) }
                    }.frame(width: 190)
                }
                Hairline()
                gamePanel
                runtimePanel
                homePanel
                aiPanel
                behaviorPanel
            }
            .padding(32).frame(maxWidth: 900)
        }.frame(maxWidth: .infinity)
        .onAppear {
            apiKey = settings.apiKey
            endpointDraft = settings.endpoint
        }
        .onDisappear { completeEndpoint() }
    }

    private var gamePanel: some View {
        Panel {
            VStack(alignment: .leading, spacing: 18) {
                panelHeading("Minecraft", detail: L10n.t("settings.game_folder"))
                LabeledField(L10n.t("settings.game_folder"), hint: L10n.t("settings.folder_hint")) {
                    HStack(spacing: 8) {
                        TextField(L10n.t("settings.game_folder"), text: $settings.gameDirectory).mioreTextField()
                        Menu(L10n.t("settings.path_presets")) {
                            Button(L10n.t("settings.official")) { model.useOfficialGameDirectory() }
                            Button(L10n.t("settings.legacy")) { settings.gameDirectory = NSString(string: "~/.minecraft").expandingTildeInPath; model.refresh() }
                        }.menuStyle(.borderlessButton).frame(width: 80)
                        Button(L10n.t("common.choose")) { model.chooseGameDirectory() }.buttonStyle(GhostButtonStyle())
                        Button(L10n.t("common.scan")) { model.refresh() }.buttonStyle(GhostButtonStyle())
                    }
                }
                HStack(spacing: 18) {
                    statusValue(L10n.t("settings.folder_status"), FileManager.default.fileExists(atPath: settings.gameDirectory) ? L10n.t("settings.accessible") : L10n.t("settings.missing"))
                    statusValue(L10n.t("settings.local_instances"), "\(model.instances.count)")
                    statusValue(L10n.t("settings.current_instance"), model.selectedInstance?.name ?? L10n.t("settings.not_selected"))
                }
                LabeledField(L10n.t("settings.offline_name"), hint: nil) {
                    TextField("Player", text: $settings.username).mioreTextField()
                }
                Hairline()
                LabeledField(L10n.t("settings.client_id"), hint: L10n.t("settings.client_hint")) {
                    TextField("xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx", text: $settings.microsoftClientID).mioreTextField()
                }
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(account.profile?.name ?? L10n.t("settings.not_signed_in")).font(.miore(size: 12, weight: .medium))
                        Text(account.profile == nil ? L10n.t("settings.offline_active") : "Minecraft: Java Edition").font(.miore(size: 9)).foregroundColor(MioreTheme.subtle)
                    }
                    Spacer()
                    Button(L10n.t("settings.import_account")) { account.importOfficialLauncher() }.buttonStyle(GhostButtonStyle())
                    if account.profile == nil || !account.isSessionValid { Button(L10n.t("common.login")) { model.beginMicrosoftLogin() }.buttonStyle(PrimaryButtonStyle(compact: true)) }
                    else { Button(L10n.t("common.logout")) { account.signOut() }.buttonStyle(GhostButtonStyle()) }
                }
                if account.isWorking { HStack { ProgressView().controlSize(.small); Text(account.status).font(.miore(size: 10)).foregroundColor(MioreTheme.muted) } }
                if let error = account.error { Text(error).font(.miore(size: 10)).foregroundColor(MioreTheme.muted) }
            }
        }
    }

    private var runtimePanel: some View {
        let required = JavaRuntimeService.requiredMajor(for: model.selectedInstance?.gameVersion)
        let recommended = javaRuntimes.recommended(for: model.selectedInstance?.gameVersion)
        return Panel {
            VStack(alignment: .leading, spacing: 18) {
                panelHeading(L10n.t("settings.java"), detail: "Java \(required)")
                HStack {
                    Toggle(L10n.t("settings.java_auto"), isOn: $settings.autoSelectJava)
                        .toggleStyle(.switch).font(.miore(size: 11)).onChange(of: settings.autoSelectJava) { enabled in if enabled { model.applyRecommendedJava() } }
                    Spacer()
                    if javaRuntimes.scanning { ProgressView().controlSize(.small) }
                    Button(L10n.t("settings.detect_again")) { javaRuntimes.scan { model.applyRecommendedJava() } }.buttonStyle(GhostButtonStyle())
                }
                if !javaRuntimes.runtimes.isEmpty {
                    LabeledField(L10n.t("settings.detected_java", javaRuntimes.runtimes.count)) {
                        Picker("", selection: $settings.javaPath) {
                            if !javaRuntimes.runtimes.contains(where: { $0.path == settings.javaPath }) {
                                Text("\(L10n.t("settings.custom")) · \(settings.javaPath)").tag(settings.javaPath)
                            }
                            ForEach(javaRuntimes.runtimes) { runtime in
                                Text("\(runtime.label) · \(runtime.version)").tag(runtime.path)
                            }
                        }.labelsHidden().frame(maxWidth: .infinity).onChange(of: settings.javaPath) { _ in
                            if settings.javaPath != recommended?.path { settings.autoSelectJava = false }
                        }
                    }
                    if let recommended {
                        Text("\(L10n.t("settings.recommended")) · \(recommended.label) · \(recommended.path)").font(.miore(size: 9, design: .monospaced)).foregroundColor(MioreTheme.subtle).textSelection(.enabled)
                    }
                } else if !javaRuntimes.scanning {
                    Text(L10n.t("settings.no_java"))
                        .font(.miore(size: 10)).foregroundColor(MioreTheme.muted)
                }
                LabeledField(L10n.t("settings.java_path")) {
                    HStack(spacing: 8) {
                        TextField("/path/to/bin/java", text: $settings.javaPath).mioreTextField()
                        Button(L10n.t("common.choose")) { model.chooseJava() }.buttonStyle(GhostButtonStyle())
                    }
                }
                LabeledField("Maximum memory · \(Int(settings.memoryMB)) MB", hint: "Physical memory \(physicalMemoryGB) GB; large modpacks usually need 6–8 GB.") {
                    Slider(value: $settings.memoryMB, in: 1024...memoryUpperBound, step: 512).tint(MioreTheme.accent)
                }
            }
        }
    }

    private var homePanel: some View {
        Panel {
            VStack(alignment: .leading, spacing: 18) {
                panelHeading(L10n.t("settings.home"), detail: "")
                HStack(spacing: 24) {
                    ColorPicker(L10n.t("settings.background"), selection: Binding(get: { Color(hex: settings.homeBackgroundHex) }, set: { settings.homeBackgroundHex = $0.hexString }), supportsOpacity: false)
                    ColorPicker(L10n.t("settings.accent"), selection: Binding(get: { Color(hex: settings.homeAccentHex) }, set: { settings.homeAccentHex = $0.hexString }), supportsOpacity: false)
                    Spacer()
                    Button(L10n.t("settings.restore")) { settings.resetHomeLayout() }.buttonStyle(GhostButtonStyle())
                    Button {
                        model.editingHome = true
                        model.section = .home
                    } label: {
                        Label(L10n.t("settings.manage_widgets"), systemImage: "square.grid.2x2")
                    }
                    .buttonStyle(PrimaryButtonStyle(compact: true, color: Color(hex: settings.homeAccentHex)))
                }.font(.miore(size: 11))
                Text(L10n.t("settings.layout_hint"))
                    .font(.miore(size: 10)).foregroundColor(MioreTheme.subtle)
            }
        }
    }

    private var aiPanel: some View {
        Panel {
            VStack(alignment: .leading, spacing: 18) {
                panelHeading(L10n.t("settings.ai"), detail: "AI")
                HStack(alignment: .top, spacing: 18) {
                    LabeledField(L10n.t("settings.provider")) {
                        Picker("", selection: Binding(
                            get: { settings.provider },
                            set: { provider in
                                completeEndpoint()
                                settings.provider = provider
                                endpointDraft = settings.endpoint
                            }
                        )) {
                            ForEach(AIProvider.allCases) { provider in Text(provider.displayName).tag(provider) }
                        }.labelsHidden().frame(maxWidth: .infinity)
                    }
                    LabeledField(L10n.t("settings.model")) { TextField("model", text: $settings.model).mioreTextField() }
                }
                LabeledField("API Endpoint", hint: settings.provider == .custom ? "Enter an OpenAI Chat Completions-compatible endpoint." : nil) {
                    HStack(spacing: 8) {
                        TextField("https://…", text: $endpointDraft)
                            .focused($endpointFocused)
                            .onSubmit { completeEndpoint() }
                            .onChange(of: endpointFocused) { focused in if !focused { completeEndpoint() } }
                            .mioreTextField()
                        Button(savedEndpoint ? "✓" : L10n.t("settings.save_endpoint")) { completeEndpoint(showConfirmation: true) }
                            .buttonStyle(PrimaryButtonStyle(compact: true))
                    }
                }
                LabeledField("API Key", hint: "Stored in Miore’s local config. Ollama can leave this empty.") {
                    HStack(spacing: 8) {
                        SecureField("sk-…", text: $apiKey).mioreTextField()
                        Button(savedKey ? "✓" : L10n.t("settings.save_key")) {
                            settings.apiKey = apiKey; savedKey = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { savedKey = false }
                        }.buttonStyle(PrimaryButtonStyle(compact: true))
                    }
                }
                Toggle(L10n.t("settings.greeting"), isOn: $settings.aiGreeting).toggleStyle(.switch).font(.miore(size: 12))
            }
        }
    }

    private var behaviorPanel: some View {
        Panel {
            VStack(alignment: .leading, spacing: 15) {
                panelHeading(L10n.t("settings.privacy"), detail: "")
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lock.shield").foregroundColor(MioreTheme.muted)
                    Text(L10n.t("settings.privacy_detail"))
                        .font(.miore(size: 11)).foregroundColor(MioreTheme.muted).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func panelHeading(_ title: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.miore(size: 15, weight: .medium))
            Spacer()
            Text(detail).font(.miore(size: 10)).foregroundColor(MioreTheme.subtle)
        }
    }

    private var physicalMemoryGB: Int { Int(ProcessInfo.processInfo.physicalMemory / 1_073_741_824) }
    private var memoryUpperBound: Double { Double(max(2048, min(32768, Int(ProcessInfo.processInfo.physicalMemory / 1_048_576)))) }

    private func completeEndpoint(showConfirmation: Bool = false) {
        settings.persistAIEndpoint(endpointDraft)
        endpointDraft = settings.endpoint
        guard showConfirmation else { return }
        savedEndpoint = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { savedEndpoint = false }
    }

    private func statusValue(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.miore(size: 9)).foregroundColor(MioreTheme.subtle)
            Text(value).font(.miore(size: 11, weight: .medium)).lineLimit(1)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
