import Testing
import Foundation
import SwiftUI
import AppKit
@testable import Miore

@Test func registersBundledGoogleFont() {
    #expect(MioreFont.registerBundledFont())
    #expect(NSFont(name: MioreFont.familyName, size: 12) != nil)
}

@Test func rewritesMinecraftDownloadMirrors() throws {
    #expect(MinecraftDownloadRouter.mirrorURL(for: URL(string: "https://piston-meta.mojang.com/v1/packages/a/version.json")!)?.absoluteString == "https://bmclapi2.bangbang93.com/v1/packages/a/version.json")
    #expect(MinecraftDownloadRouter.mirrorURL(for: URL(string: "https://libraries.minecraft.net/com/example/demo.jar")!)?.absoluteString == "https://bmclapi2.bangbang93.com/maven/com/example/demo.jar")
    #expect(MinecraftDownloadRouter.mirrorURL(for: URL(string: "https://resources.download.minecraft.net/ab/hash")!)?.absoluteString == "https://bmclapi2.bangbang93.com/assets/ab/hash")
    #expect(MinecraftDownloadRouter.mirrorURL(for: URL(string: "https://example.com/file.jar")!) == nil)
}

@Test func rejectsUnsafeContentFilenames() throws {
    #expect(try ModrinthService.validatedContentFilename("sodium.jar") == "sodium.jar")
    #expect(throws: ModrinthError.self) { try ModrinthService.validatedContentFilename("../escape.jar") }
    #expect(throws: ModrinthError.self) { try ModrinthService.validatedContentFilename("folder/escape.jar") }
    #expect(throws: ModrinthError.self) { try ModrinthService.validatedContentFilename(#"folder\escape.jar"#) }
}

@Test func loaderDetection() {
    #expect(LoaderKind.detect(versionID: "fabric-loader-0.16.10-1.21.4", json: [:]) == .fabric)
    #expect(LoaderKind.detect(versionID: "1.20.1-forge-47.3.0", json: [:]) == .forge)
    #expect(LoaderKind.detect(versionID: "1.21.1", json: [:]) == .vanilla)
}

@Test func sanitizesSecretsAndHome() {
    let source = "Authorization: abc123 path=\(NSHomeDirectory())/Library api_key=secret"
    let result = AIService.sanitize(source)
    #expect(!result.contains("abc123"))
    #expect(!result.contains("secret"))
    #expect(!result.contains(NSHomeDirectory()))
}

@Test func nativeClassifierUsesMacArchitectures() {
    #expect(NativeClassifier.candidates(template: "natives-macos-${arch}", architecture: "arm64") == ["natives-macos-arm64", "natives-macos-x86_64", "natives-macos-64", "natives-macos"])
}

@Test func completesAIProviderEndpoints() {
    #expect(AIProvider.deepSeek.completedEndpoint("https://api.deepseek.com") == "https://api.deepseek.com/v1/chat/completions")
    #expect(AIProvider.custom.completedEndpoint("https://example.com/v1") == "https://example.com/v1/chat/completions")
    #expect(AIProvider.anthropic.completedEndpoint("https://api.anthropic.com") == "https://api.anthropic.com/v1/messages")
    #expect(AIProvider.custom.completedEndpoint("https://example.com/custom/generate") == "https://example.com/custom/generate")
}

@Test func validatesModpackMinecraftVersionAndLoader() throws {
    let plan = try ModrinthService.modpackPlan(
        dependencies: ["minecraft": "1.21.1", "fabric-loader": "0.16.10"],
        selectedGameVersion: "1.21.1"
    )
    #expect(plan == ModpackInstallPlan(loader: .fabric, gameVersion: "1.21.1"))
    #expect(throws: ModrinthError.self) {
        try ModrinthService.modpackPlan(
            dependencies: ["minecraft": "1.20.1", "forge": "47.4.0"],
            selectedGameVersion: "1.21.1"
        )
    }
}

@Test func decodesModrinthSearchProject() throws {
    let json = #"{"project_id":"AANobbMI","project_type":"mod","slug":"sodium","title":"Sodium","description":"Fast","author":"CaffeineMC","downloads":42}"#
    let decoder = JSONDecoder()
    let project = try decoder.decode(ModrinthProject.self, from: Data(json.utf8))
    #expect(project.id == "AANobbMI")
    #expect(project.projectType == "mod")
}

@Test func decodesModrinthSearchEnvelope() throws {
    let json = #"{"hits":[{"project_id":"AANobbMI","project_type":"mod","slug":"sodium","title":"Sodium","description":"Fast","author":"CaffeineMC","downloads":42}]}"#
    let projects = try ModrinthService.decodeSearchResults(Data(json.utf8))
    #expect(projects.first?.slug == "sodium")
}

@MainActor @Test func createsMavenLibraryPath() {
    #expect(LoaderInstaller.mavenPath("net.fabricmc:fabric-loader:0.16.0") == "net/fabricmc/fabric-loader/0.16.0/fabric-loader-0.16.0.jar")
}

@Test func recommendsJavaForMinecraftVersions() {
    #expect(JavaRuntimeService.requiredMajor(for: "1.16.5") == 8)
    #expect(JavaRuntimeService.requiredMajor(for: "1.17.1") == 16)
    #expect(JavaRuntimeService.requiredMajor(for: "1.20.1") == 17)
    #expect(JavaRuntimeService.requiredMajor(for: "1.20.5") == 21)
    #expect(JavaRuntimeService.requiredMajor(for: "1.21.11") == 21)
    #expect(JavaRuntimeService.requiredMajor(for: "26.1") == 21)
}

@Test func themeUsesReadableButtonText() {
    let onBlack = NSColor(MioreTheme.contrastText(for: .black)).usingColorSpace(.deviceRGB)
    let onWhite = NSColor(MioreTheme.contrastText(for: .white)).usingColorSpace(.deviceRGB)
    #expect((onBlack?.redComponent ?? 0) > 0.9)
    #expect((onWhite?.redComponent ?? 1) < 0.1)
}

@Test func supportsFourUILanguages() {
    let config = LocalConfigStore.shared
    let previous = config.string(forKey: "appLanguage")
    defer {
        if let previous { config.set(previous, forKey: "appLanguage") }
        else { config.removeObject(forKey: "appLanguage") }
    }
    config.set("en", forKey: "appLanguage")
    #expect(L10n.t("home.welcome") == "Welcome back.")
    #expect(L10n.t("console.waiting") == "Waiting for launch output…")
    config.set("ja", forKey: "appLanguage")
    #expect(L10n.t("home.welcome") == "おかえりなさい。")
    #expect(L10n.t("log.stop_requested") == "ゲームの停止を要求しました。")
    config.set("zhHant", forKey: "appLanguage")
    #expect(L10n.t("home.welcome") == "歡迎回來。")
    config.set("zhHans", forKey: "appLanguage")
    #expect(L10n.t("home.welcome") == "欢迎回来。")
    #expect(L10n.t("instances.delete_detail", "fabric-loader-1.21.1").contains("fabric-loader-1.21.1"))
}

@MainActor @Test func resetHomeLayoutRestoresWidgets() {
    let settings = SettingsStore()
    settings.showHomeProfile = false
    settings.showHomeClock = false
    settings.showHomeInstanceWidget = false
    settings.showHomeRuntimeWidget = false
    settings.resetHomeLayout()
    #expect(settings.showHomeProfile)
    #expect(settings.showHomeClock)
    #expect(settings.showHomeInstanceWidget)
    #expect(settings.showHomeRuntimeWidget)
}

@Test func scansInstalledFabricInstance() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("miore-scanner-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let id = "fabric-loader-0.16.0-1.21.1"
    let directory = root.appendingPathComponent("versions/\(id)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let json = #"{"id":"fabric-loader-0.16.0-1.21.1","inheritsFrom":"1.21.1","mainClass":"net.fabricmc.loader.impl.launch.knot.KnotClient"}"#
    try Data(json.utf8).write(to: directory.appendingPathComponent("\(id).json"))
    let instances = InstanceScanner.scan(gameDirectory: root.path)
    #expect(instances.count == 1)
    #expect(instances.first?.loader == .fabric)
    #expect(instances.first?.gameVersion == "1.21.1")
}

@Test func decodesMojangVersionManifest() throws {
    let json = #"{"versions":[{"id":"1.21.1","type":"release","url":"https://example.invalid/1.21.1.json","releaseTime":"2024-08-08T12:00:00Z"}]}"#
    let versions = try VersionInstaller.decodeManifest(Data(json.utf8))
    #expect(versions.first?.id == "1.21.1")
    #expect(versions.first?.type == "release")
}

@Test func selectsStableOptiFineDownloadForExactMinecraftVersion() {
    let html = #"""
    <a href="adloadx?f=preview_OptiFine_1.21.1_HD_U_J2_pre1.jar">Preview</a>
    <a href="adloadx?f=OptiFine_1.21_HD_U_J1.jar">Wrong exact version</a>
    <a href="adloadx?f=OptiFine_1.21.1_HD_U_J2.jar">Stable</a>
    """#
    #expect(LoaderInstaller.optiFineFileName(in: Data(html.utf8), gameVersion: "1.21.1") == "OptiFine_1.21.1_HD_U_J2.jar")
    #expect(LoaderInstaller.optiFineFileName(in: Data(html.utf8), gameVersion: "1.21") == "OptiFine_1.21_HD_U_J1.jar")
    #expect(LoaderInstaller.optiFineFileName(in: Data(html.utf8), gameVersion: "1.20.1") == nil)
}

@Test func parsesOptiFineTokenizedDownloadURL() {
    let html = #"<a href='downloadx?f=OptiFine_1.20.1_HD_U_I6.jar&x=239a0dbc85e21d8e'>Download</a>"#
    let url = LoaderInstaller.optiFineDownloadURL(in: Data(html.utf8), fileName: "OptiFine_1.20.1_HD_U_I6.jar")
    #expect(url?.absoluteString == "https://optifine.net/downloadx?f=OptiFine_1.20.1_HD_U_I6.jar&x=239a0dbc85e21d8e")
}

@Test func fallsBackToOptiFinePreviewWhenNoStableBuildExists() {
    let html = #"<a href="adloadx?f=preview_OptiFine_26.1.2_HD_U_K1_pre2.jar">Preview</a>"#
    #expect(LoaderInstaller.optiFineFileName(in: Data(html.utf8), gameVersion: "26.1.2") == "preview_OptiFine_26.1.2_HD_U_K1_pre2.jar")
}

@MainActor @Test func mapsMinecraftVersionsToExactNeoForgeSeries() {
    #expect(LoaderInstaller.neoForgePrefix(for: "1.21") == "21.0.")
    #expect(LoaderInstaller.neoForgePrefix(for: "1.21.1") == "21.1.")
    #expect(LoaderInstaller.neoForgePrefix(for: "1.20") == "20.0.")
    #expect(LoaderInstaller.neoForgePrefix(for: "1.20.1") == "20.1.")
}
