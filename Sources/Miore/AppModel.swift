import Foundation
import AppKit

@MainActor
final class AppModel: ObservableObject {
    let settings: SettingsStore
    let launcher: MinecraftLauncher
    let ai: AIService
    let installer = VersionInstaller()
    let account: MicrosoftAccountService
    let loaderInstaller = LoaderInstaller()
    let contentService = ModrinthService()
    let javaRuntimes = JavaRuntimeService()

    @Published var section: AppSection = .home
    @Published var instances: [GameInstance] = []
    @Published var selectedInstanceID: String?
    @Published var notice: String?
    @Published var editingHome = false
    @Published var showAccountLogin = false

    init() {
        let settings = SettingsStore()
        self.settings = settings
        launcher = MinecraftLauncher()
        ai = AIService(settings: settings)
        account = MicrosoftAccountService(settings: settings)
        ai.setAccountNameProvider { [weak account, weak settings] in
            account?.profile?.name ?? settings?.username ?? "Player"
        }
        refresh()
        javaRuntimes.scan { [weak self] in self?.applyRecommendedJava() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self else { return }
            self.ai.greet(instanceCount: self.instances.count)
        }
    }

    var selectedInstance: GameInstance? {
        if let selectedInstanceID, let exact = instances.first(where: { $0.id == selectedInstanceID }) { return exact }
        return instances.first
    }

    func refresh() {
        let scanned = InstanceScanner.scan(gameDirectory: settings.gameDirectory)
        instances = scanned
        if selectedInstanceID == nil || !scanned.contains(where: { $0.id == selectedInstanceID }) {
            selectedInstanceID = scanned.first?.id
        }
        applyRecommendedJava()
    }

    func selectInstance(_ id: String) {
        selectedInstanceID = id
        applyRecommendedJava()
    }

    func deleteInstance(_ instance: GameInstance) throws {
        guard !instance.versionDirectory.path.isEmpty,
              instance.versionDirectory.deletingLastPathComponent().lastPathComponent == "versions" else {
            throw CocoaError(.fileNoSuchFile)
        }
        try FileManager.default.trashItem(at: instance.versionDirectory, resultingItemURL: nil)
        if selectedInstanceID == instance.id { selectedInstanceID = nil }
        refresh()
    }

    func applyRecommendedJava() {
        guard settings.autoSelectJava, let runtime = javaRuntimes.recommended(for: selectedInstance?.gameVersion) else { return }
        settings.javaPath = runtime.path
    }

    func changeLanguage(_ language: AppLanguage) {
        guard settings.appLanguage != language else { return }
        settings.appLanguage = language
        objectWillChange.send()
        launcher.languageDidChange()
        ai.languageDidChange(instanceCount: instances.count)
    }

    func launchSelected() {
        guard let instance = selectedInstance else {
            notice = "No launchable instance was found. Please choose the correct .minecraft folder in Settings."
            return
        }
        section = .console
        launcher.launch(instance: instance, settings: settings, credentials: account.credentials)
    }

    func chooseGameDirectory() {
        let panel = NSOpenPanel()
        panel.title = "Choose a Minecraft game folder"
        panel.prompt = "Choose"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: NSString(string: settings.gameDirectory).expandingTildeInPath)
        if panel.runModal() == .OK, let url = panel.url {
            settings.gameDirectory = url.path
            refresh()
        }
    }

    func useOfficialGameDirectory() {
        settings.gameDirectory = SettingsStore.officialGameDirectory
        refresh()
    }

    func beginMicrosoftLogin() {
        showAccountLogin = true
    }

    func chooseJava() {
        let panel = NSOpenPanel()
        panel.title = "Choose the Java executable"
        panel.prompt = "Choose"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            settings.javaPath = url.path
            settings.autoSelectJava = false
        }
    }
}
