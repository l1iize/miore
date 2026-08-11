import Foundation
import CryptoKit
import Darwin

enum LaunchError: LocalizedError {
    case missingVersionJSON
    case invalidVersionJSON
    case missingMainClass
    case missingJava(String)
    case missingLibraries([String])

    var errorDescription: String? {
        switch self {
        case .missingVersionJSON: return L10n.language.resolved == .en ? "Version JSON is missing." : (L10n.language.resolved == .ja ? "バージョン JSON がありません。" : "Version JSON is missing.")
        case .invalidVersionJSON: return L10n.language.resolved == .en ? "The version JSON is invalid." : (L10n.language.resolved == .ja ? "The version JSON is invalid." : "The version JSON is invalid.")
        case .missingMainClass: return L10n.language.resolved == .en ? "mainClass is missing from the version profile." : (L10n.language.resolved == .ja ? "mainClass is missing from the version profile." : "mainClass is missing from the version profile.")
        case .missingJava(let path): return L10n.language.resolved == .en ? "Java was not found: \(path)" : (L10n.language.resolved == .ja ? "Java was not found: \(path)" : "Java was not found: \(path)")
        case .missingLibraries(let paths):
            let preview = paths.prefix(4).joined(separator: "\n")
            return "The instance is missing \(paths.count) libraries:\n\n\(preview)"
        }
    }
}

final class MinecraftLauncher: ObservableObject {
    @Published private(set) var state: LaunchState = .idle
    @Published private(set) var output = ""
    private var process: Process?
    private var launchPreparationInProgress = false
    private var stopRequested = false
    private var launchGeneration = 0

    func clearOutput() { output = "" }

    func stop() {
        stopRequested = true
        launchGeneration += 1
        if process == nil, launchPreparationInProgress {
            launchPreparationInProgress = false
            state = .idle
            append("[Miore] \(L10n.t("log.stop_requested"))\n")
            return
        }
        guard let process else { return }
        process.terminate()
        state = .preparing
        append("[Miore] \(L10n.t("log.stop_requested"))\n")
        let pid = process.processIdentifier
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 5) { [weak self, weak process] in
            guard let self, let process, process.isRunning else { return }
            DispatchQueue.main.async {
                guard self.process === process, self.stopRequested else { return }
                Darwin.kill(pid, SIGKILL)
            }
        }
    }

    func languageDidChange() {
        guard !output.isEmpty else { return }
        let minecraftLines = output.split(separator: "\n", omittingEmptySubsequences: false).filter { !$0.hasPrefix("[Miore]") }
        let raw = minecraftLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        output = "[Miore] \(L10n.t("console.language_changed"))\n" + (raw.isEmpty ? "" : "\n\(raw)\n")
    }

    func launch(instance: GameInstance, settings: SettingsStore, credentials: MinecraftCredentials?) {
        guard process == nil, !launchPreparationInProgress else { return }
        launchPreparationInProgress = true
        stopRequested = false
        launchGeneration += 1
        let generation = launchGeneration
        state = .preparing
        append("[Miore] \(L10n.t("log.preparing", instance.id))\n")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let descriptor = try LaunchDescriptor.build(instance: instance, settings: settings, credentials: credentials)
                let task = Process()
                task.executableURL = URL(fileURLWithPath: settings.javaPath)
                task.arguments = descriptor.arguments
                task.currentDirectoryURL = descriptor.gameDirectory
                task.environment = ProcessInfo.processInfo.environment.merging(descriptor.environment) { _, new in new }

                let pipe = Pipe()
                task.standardOutput = pipe
                task.standardError = pipe
                pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                    let data = handle.availableData
                    guard !data.isEmpty else { return }
                    let text = String(decoding: data, as: UTF8.self)
                    DispatchQueue.main.async { self?.append(text) }
                }
                task.terminationHandler = { [weak self] finished in
                    pipe.fileHandleForReading.readabilityHandler = nil
                    DispatchQueue.main.async {
                        guard let self else { return }
                        self.append("\n[Miore] \(L10n.t("log.ended", finished.terminationStatus))\n")
                        self.process = nil
                        let wasStopped = self.stopRequested
                        self.stopRequested = false
                        self.state = finished.terminationStatus == 0 || wasStopped ? .idle : .failed("Minecraft exit code \(finished.terminationStatus)")
                    }
                }
                DispatchQueue.main.sync {
                    guard let self, self.launchGeneration == generation, !self.stopRequested else { return }
                    self.process = task
                    self.launchPreparationInProgress = false
                }
                guard self?.process === task else { return }
                do {
                    try task.run()
                } catch {
                    DispatchQueue.main.sync {
                        self?.process = nil
                        self?.launchPreparationInProgress = false
                    }
                    throw error
                }
                DispatchQueue.main.async {
                    guard let self, self.process === task, task.isRunning else { return }
                    self.state = .running(pid: task.processIdentifier)
                    self.append("[Miore] \(L10n.t("log.started", task.processIdentifier))\n\n")
                }
            } catch {
                DispatchQueue.main.async {
                    self?.launchPreparationInProgress = false
                    self?.state = .failed(error.localizedDescription)
                    self?.append("[Miore] \(L10n.t("log.failed", error.localizedDescription))\n")
                }
            }
        }
    }

    private func append(_ text: String) {
        output += text
        if output.count > 600_000 { output = String(output.suffix(450_000)) }
    }
}

private struct LaunchDescriptor {
    let arguments: [String]
    let environment: [String: String]
    let gameDirectory: URL

    static func build(instance: GameInstance, settings: SettingsStore, credentials: MinecraftCredentials?) throws -> LaunchDescriptor {
        let fm = FileManager.default
        guard fm.isExecutableFile(atPath: settings.javaPath) else { throw LaunchError.missingJava(settings.javaPath) }
        let root = URL(fileURLWithPath: NSString(string: settings.gameDirectory).expandingTildeInPath)
        let resolved = try VersionResolver.resolve(id: instance.id, root: root)
        guard let mainClass = resolved.json["mainClass"] as? String else { throw LaunchError.missingMainClass }

        let nativeDir = root.appendingPathComponent("natives/miore-\(safe(instance.id))", isDirectory: true)
        try fm.createDirectory(at: nativeDir, withIntermediateDirectories: true)
        let libraries = try resolveLibraries(json: resolved.json, root: root, nativeDir: nativeDir)
        let versionJar = resolved.clientJar
        var classpath = libraries.classpath
        classpath.append(versionJar.path)
        let missing = classpath.filter { !fm.fileExists(atPath: $0) }
        if !missing.isEmpty { throw LaunchError.missingLibraries(missing) }

        let playerName = credentials?.username ?? settings.username
        let uuid = credentials?.uuid ?? offlineUUID(playerName)
        let accessToken = credentials?.accessToken ?? "0"
        let assetIndex = ((resolved.json["assetIndex"] as? [String: Any])?["id"] as? String)
            ?? (resolved.json["assets"] as? String) ?? "legacy"
        let values: [String: String] = [
            "auth_player_name": playerName,
            "version_name": instance.id,
            "game_directory": root.path,
            "assets_root": root.appendingPathComponent("assets").path,
            "assets_index_name": assetIndex,
            "auth_uuid": uuid,
            "auth_access_token": accessToken,
            "auth_session": "token:\(accessToken):\(uuid)",
            "user_type": credentials == nil ? "legacy" : "msa",
            "version_type": "Miore",
            "classpath": classpath.joined(separator: ":"),
            "classpath_separator": ":",
            "library_directory": root.appendingPathComponent("libraries").path,
            "primary_jar": versionJar.path,
            "natives_directory": nativeDir.path,
            "launcher_name": "Miore",
            "launcher_version": "0.1.0",
            "user_properties": "{}",
            "clientid": "",
            "auth_xuid": ""
        ]

        var jvm = ["-Xms512M", "-Xmx\(Int(settings.memoryMB))M", "-Dfile.encoding=UTF-8"]
        var game: [String] = []
        if let arguments = resolved.json["arguments"] as? [String: Any] {
            jvm += parseArguments(arguments["jvm"] as? [Any] ?? [], values: values)
            game += parseArguments(arguments["game"] as? [Any] ?? [], values: values)
        } else if let legacy = resolved.json["minecraftArguments"] as? String {
            game += shellSplit(legacy).map { replace($0, values: values) }
            jvm += ["-Djava.library.path=\(nativeDir.path)", "-cp", values["classpath"]!]
        }
        if !jvm.contains("-cp") && !jvm.contains("-classpath") {
            jvm += ["-cp", values["classpath"]!]
        }
        return LaunchDescriptor(
            arguments: jvm + [mainClass] + game,
            environment: ["MIORE_INSTANCE": instance.id],
            gameDirectory: root
        )
    }

    private static func resolveLibraries(json: [String: Any], root: URL, nativeDir: URL) throws -> (classpath: [String], natives: [String]) {
        var classpath: [String] = []
        var natives: [String] = []
        let libraryRoot = root.appendingPathComponent("libraries")
        for item in json["libraries"] as? [[String: Any]] ?? [] {
            guard rulesAllow(item["rules"] as? [[String: Any]]) else { continue }
            let downloads = item["downloads"] as? [String: Any]
            if let artifact = downloads?["artifact"] as? [String: Any], let path = artifact["path"] as? String {
                classpath.append(libraryRoot.appendingPathComponent(path).path)
            } else if let name = item["name"] as? String, item["natives"] == nil, let path = mavenPath(name) {
                classpath.append(libraryRoot.appendingPathComponent(path).path)
            }
            if let nativeMap = item["natives"] as? [String: String],
               let classifierTemplate = nativeMap["osx"],
               let classifiers = downloads?["classifiers"] as? [String: Any] {
                for classifier in NativeClassifier.candidates(template: classifierTemplate) {
                    guard let record = classifiers[classifier] as? [String: Any], let path = record["path"] as? String else { continue }
                    let archive = libraryRoot.appendingPathComponent(path)
                    if FileManager.default.fileExists(atPath: archive.path) {
                        try extract(archive: archive, destination: nativeDir)
                        natives.append(archive.path)
                        break
                    }
                }
            }
        }
        return (orderedUnique(classpath), natives)
    }

    private static func extract(archive: URL, destination: URL) throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        task.arguments = ["-x", "-k", archive.path, destination.path]
        try task.run()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else { throw CocoaError(.fileReadCorruptFile) }
    }

    private static func rulesAllow(_ rules: [[String: Any]]?) -> Bool {
        guard let rules, !rules.isEmpty else { return true }
        var allowed = false
        for rule in rules where ruleMatches(rule) {
            allowed = (rule["action"] as? String) == "allow"
        }
        return allowed
    }

    private static func ruleMatches(_ rule: [String: Any]) -> Bool {
        if let os = rule["os"] as? [String: Any] {
            if let name = os["name"] as? String, name != "osx" { return false }
            if let arch = os["arch"] as? String {
                #if arch(arm64)
                if arch != "arm64" && arch != "aarch64" { return false }
                #else
                if arch != "x86_64" { return false }
                #endif
            }
        }
        if let features = rule["features"] as? [String: Bool], features.values.contains(true) { return false }
        return true
    }

    private static func parseArguments(_ raw: [Any], values: [String: String]) -> [String] {
        var result: [String] = []
        for item in raw {
            if let value = item as? String { result.append(replace(value, values: values)); continue }
            guard let object = item as? [String: Any], rulesAllow(object["rules"] as? [[String: Any]]) else { continue }
            if let value = object["value"] as? String { result.append(replace(value, values: values)) }
            if let valuesArray = object["value"] as? [String] { result += valuesArray.map { replace($0, values: values) } }
        }
        return result
    }

    private static func replace(_ input: String, values: [String: String]) -> String {
        values.reduce(input) { value, item in value.replacingOccurrences(of: "${\(item.key)}", with: item.value) }
    }

    private static func shellSplit(_ value: String) -> [String] {
        let pattern = #"(?:[^\s\"]|\"[^\"]*\")+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return value.components(separatedBy: .whitespaces) }
        let range = NSRange(value.startIndex..., in: value)
        return regex.matches(in: value, range: range).compactMap { match in
            guard let r = Range(match.range, in: value) else { return nil }
            return String(value[r]).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }
    }

    private static func mavenPath(_ name: String) -> String? {
        let components = name.split(separator: ":").map(String.init)
        guard components.count >= 3 else { return nil }
        let group = components[0].replacingOccurrences(of: ".", with: "/")
        let artifact = components[1], version = components[2]
        let classifier = components.count > 3 ? "-\(components[3])" : ""
        return "\(group)/\(artifact)/\(version)/\(artifact)-\(version)\(classifier).jar"
    }

    private static func orderedUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }

    private static func offlineUUID(_ username: String) -> String {
        let digest = Insecure.MD5.hash(data: Data("OfflinePlayer:\(username)".utf8))
        var bytes = Array(digest)
        bytes[6] = (bytes[6] & 0x0f) | 0x30
        bytes[8] = (bytes[8] & 0x3f) | 0x80
        let hex = bytes.map { String(format: "%02x", $0) }.joined()
        return "\(hex.prefix(8))-\(hex.dropFirst(8).prefix(4))-\(hex.dropFirst(12).prefix(4))-\(hex.dropFirst(16).prefix(4))-\(hex.dropFirst(20))"
    }

    private static func safe(_ value: String) -> String {
        value.replacingOccurrences(of: "[^A-Za-z0-9._-]", with: "_", options: .regularExpression)
    }
}

private enum VersionResolver {
    struct Resolved { let json: [String: Any]; let clientJar: URL }

    static func resolve(id: String, root: URL) throws -> Resolved {
        var visited = Set<String>()
        var chain: [(String, [String: Any])] = []
        var current = id
        while !visited.contains(current) {
            visited.insert(current)
            let jsonURL = root.appendingPathComponent("versions/\(current)/\(current).json")
            guard FileManager.default.fileExists(atPath: jsonURL.path) else { throw LaunchError.missingVersionJSON }
            guard let data = try? Data(contentsOf: jsonURL),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw LaunchError.invalidVersionJSON }
            chain.append((current, json))
            guard let parent = json["inheritsFrom"] as? String else { break }
            current = parent
        }
        var merged: [String: Any] = [:]
        var librariesByName: [String: [String: Any]] = [:]
        var libraryOrder: [String] = []
        for (_, json) in chain.reversed() {
            for (key, value) in json where key != "libraries" && key != "arguments" { merged[key] = value }
            if let libs = json["libraries"] as? [[String: Any]] {
                for lib in libs {
                    let key = (lib["name"] as? String) ?? UUID().uuidString
                    if librariesByName[key] == nil { libraryOrder.append(key) }
                    librariesByName[key] = lib
                }
            }
            if let args = json["arguments"] as? [String: Any] {
                var currentArgs = merged["arguments"] as? [String: Any] ?? [:]
                for type in ["jvm", "game"] {
                    currentArgs[type] = (currentArgs[type] as? [Any] ?? []) + (args[type] as? [Any] ?? [])
                }
                merged["arguments"] = currentArgs
            }
        }
        merged["libraries"] = libraryOrder.compactMap { librariesByName[$0] }
        let childJar = root.appendingPathComponent("versions/\(id)/\(id).jar")
        let baseID = chain.last?.0 ?? id
        let baseJar = root.appendingPathComponent("versions/\(baseID)/\(baseID).jar")
        return Resolved(json: merged, clientJar: FileManager.default.fileExists(atPath: childJar.path) ? childJar : baseJar)
    }
}
