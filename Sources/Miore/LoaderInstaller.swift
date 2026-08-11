import Foundation

enum InstallableLoader: String, CaseIterable, Identifiable {
    case fabric = "Fabric"
    case quilt = "Quilt"
    case forge = "Forge"
    case neoForge = "NeoForge"
    case optiFine = "OptiFine"
    var id: String { rawValue }
    var detail: String {
        switch self {
        case .fabric: return L10n.t("loader.fabric_detail")
        case .quilt: return L10n.t("loader.quilt_detail")
        case .forge: return L10n.t("loader.forge_detail")
        case .neoForge: return L10n.t("loader.neoforge_detail")
        case .optiFine: return L10n.t("loader.optifine_detail")
        }
    }
}

enum LoaderInstallError: LocalizedError {
    case noBaseVersion, invalidMetadata, noCompatibleVersion, neoForgeUnavailable1201, processFailed(String)
    var errorDescription: String? {
        switch self {
        case .noBaseVersion: return "Please install and select a vanilla Minecraft instance first."
        case .invalidMetadata: return "The loader service returned invalid metadata."
        case .noCompatibleVersion: return "No compatible loader was found for this Minecraft version."
        case .neoForgeUnavailable1201: return "NeoForge does not publish an installer for Minecraft 1.20.1. Use Forge for this version."
        case .processFailed(let output): return "The installer failed: \(output.suffix(1200))"
        }
    }
}

@MainActor
final class LoaderInstaller: ObservableObject {
    @Published private(set) var installing: InstallableLoader?
    @Published private(set) var status = ""
    @Published var error: String?

    func install(_ loader: InstallableLoader, gameVersion: String?, gameDirectory: String, javaPath: String, completion: @escaping () -> Void) {
        guard installing == nil else { return }
        guard let gameVersion, !gameVersion.isEmpty else { error = LoaderInstallError.noBaseVersion.localizedDescription; return }
        installing = loader; error = nil; status = "Checking \(loader.rawValue) version"
        Task {
            do {
                switch loader {
                case .fabric, .quilt:
                    try await installProfileLoader(loader, gameVersion: gameVersion, gameDirectory: gameDirectory)
                case .forge:
                    try await installForge(gameVersion: gameVersion, gameDirectory: gameDirectory, javaPath: javaPath, neo: false)
                case .neoForge:
                    try await installForge(gameVersion: gameVersion, gameDirectory: gameDirectory, javaPath: javaPath, neo: true)
                case .optiFine:
                    try await installOptiFine(gameVersion: gameVersion, javaPath: javaPath)
                }
                status = "All done ♡"; installing = nil; completion()
            } catch {
                self.error = error.localizedDescription; self.status = "Installation failed"; self.installing = nil
            }
        }
    }

    private func installOptiFine(gameVersion: String, javaPath: String) async throws {
        status = "Finding OptiFine for Minecraft \(gameVersion)"
        var request = URLRequest(url: URL(string: "https://optifine.net/downloads")!)
        request.setValue("Miore/0.1 (+https://github.com/l1iize/miore)", forHTTPHeaderField: "User-Agent")
        let (pageData, pageResponse) = try await URLSession.shared.data(for: request)
        try Self.validate(pageResponse)
        guard let fileName = Self.optiFineFileName(in: pageData, gameVersion: gameVersion) else {
            throw LoaderInstallError.noCompatibleVersion
        }

        var landingComponents = URLComponents(string: "https://optifine.net/adloadx")!
        landingComponents.queryItems = [URLQueryItem(name: "f", value: fileName)]
        guard let landingURL = landingComponents.url else { throw LoaderInstallError.invalidMetadata }
        var landingRequest = URLRequest(url: landingURL)
        landingRequest.setValue("Miore/0.1 (+https://github.com/l1iize/miore)", forHTTPHeaderField: "User-Agent")
        let (landingData, landingResponse) = try await URLSession.shared.data(for: landingRequest)
        try Self.validate(landingResponse)
        guard let downloadURL = Self.optiFineDownloadURL(in: landingData, fileName: fileName) else {
            throw LoaderInstallError.invalidMetadata
        }

        status = "Downloading \(fileName)"
        var downloadRequest = URLRequest(url: downloadURL)
        downloadRequest.setValue("Miore/0.1 (+https://github.com/l1iize/miore)", forHTTPHeaderField: "User-Agent")
        downloadRequest.setValue(landingURL.absoluteString, forHTTPHeaderField: "Referer")
        let (temporary, response) = try await URLSession.shared.download(for: downloadRequest)
        try Self.validate(response)

        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)
        let destination = downloads.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: temporary, to: destination)
        guard Self.isJAR(destination) else {
            try? FileManager.default.removeItem(at: destination)
            throw LoaderInstallError.invalidMetadata
        }

        status = "Opening the official OptiFine installer"
        try await runJavaInstaller(javaPath: javaPath, arguments: ["-Xmx1G", "-jar", destination.path])
    }

    nonisolated static func optiFineFileName(in data: Data, gameVersion: String) -> String? {
        let html = String(decoding: data, as: UTF8.self)
        let pattern = #"(?:preview_)?OptiFine_([0-9]+(?:\.[0-9]+)*)_HD_U_[A-Za-z0-9_]+\.jar"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(html.startIndex..., in: html)
        var seen = Set<String>()
        var stable: [String] = []
        var previews: [String] = []
        for match in regex.matches(in: html, range: range) {
            guard let wholeRange = Range(match.range(at: 0), in: html),
                  let versionRange = Range(match.range(at: 1), in: html),
                  String(html[versionRange]) == gameVersion else { continue }
            let fileName = String(html[wholeRange])
            guard seen.insert(fileName).inserted else { continue }
            if fileName.hasPrefix("preview_") { previews.append(fileName) }
            else { stable.append(fileName) }
        }
        return stable.first ?? previews.first
    }

    nonisolated static func optiFineDownloadURL(in data: Data, fileName: String) -> URL? {
        let html = String(decoding: data, as: UTF8.self)
        let escaped = NSRegularExpression.escapedPattern(for: fileName)
        let pattern = #"downloadx\?f=\#(escaped)&amp;?x=([A-Za-z0-9]+)|downloadx\?f=\#(escaped)&x=([A-Za-z0-9]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)) else { return nil }
        let tokenRange = match.range(at: 1).location != NSNotFound ? match.range(at: 1) : match.range(at: 2)
        guard let token = Range(tokenRange, in: html) else { return nil }
        var components = URLComponents(string: "https://optifine.net/downloadx")
        components?.queryItems = [URLQueryItem(name: "f", value: fileName), URLQueryItem(name: "x", value: String(html[token]))]
        return components?.url
    }

    private static func isJAR(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        guard let prefix = try? handle.read(upToCount: 4), prefix.count == 4 else { return false }
        return prefix[0] == 0x50 && prefix[1] == 0x4B && [0x03, 0x05, 0x07].contains(prefix[2])
    }

    private func runJavaInstaller(javaPath: String, arguments: [String]) async throws {
        let logURL = FileManager.default.temporaryDirectory.appendingPathComponent("miore-installer-\(UUID().uuidString).log")
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        let log = try FileHandle(forWritingTo: logURL)
        defer {
            try? log.close()
            try? FileManager.default.removeItem(at: logURL)
        }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: javaPath)
        task.arguments = arguments
        task.standardOutput = log
        task.standardError = log
        do { try task.run() }
        catch { throw LoaderInstallError.processFailed(error.localizedDescription) }
        let terminationStatus = await Task.detached(priority: .userInitiated) {
            task.waitUntilExit()
            return task.terminationStatus
        }.value
        try? log.synchronize()
        let output = (try? String(contentsOf: logURL, encoding: .utf8)) ?? ""
        guard terminationStatus == 0 else { throw LoaderInstallError.processFailed(output) }
    }

    private func installProfileLoader(_ loader: InstallableLoader, gameVersion: String, gameDirectory: String) async throws {
        let isFabric = loader == .fabric
        let base = isFabric ? "https://meta.fabricmc.net/v2" : "https://meta.quiltmc.org/v3"
        guard let listURL = URL(string: "\(base)/versions/loader/\(gameVersion)") else { throw LoaderInstallError.invalidMetadata }
        let (listData, response) = try await URLSession.shared.data(from: listURL); try Self.validate(response)
        guard let options = try JSONSerialization.jsonObject(with: listData) as? [[String: Any]] else { throw LoaderInstallError.noCompatibleVersion }
        let candidates = options.filter { !isFabric || (($0["loader"] as? [String: Any])?["stable"] as? Bool == true) }
        guard let chosen = candidates.max(by: {
                  let lhs = (($0["loader"] as? [String: Any])?["version"] as? String) ?? "0"
                  let rhs = (($1["loader"] as? [String: Any])?["version"] as? String) ?? "0"
                  return Self.numericVersion(lhs).lexicographicallyPrecedes(Self.numericVersion(rhs))
              }),
              let loaderVersion = (chosen["loader"] as? [String: Any])?["version"] as? String,
              let profileURL = URL(string: "\(base)/versions/loader/\(gameVersion)/\(loaderVersion)/profile/json") else { throw LoaderInstallError.noCompatibleVersion }
        status = "Creating \(loader.rawValue) launch profile"
        let (profileData, profileResponse) = try await URLSession.shared.data(from: profileURL); try Self.validate(profileResponse)
        guard let profile = try JSONSerialization.jsonObject(with: profileData) as? [String: Any],
              let profileID = profile["id"] as? String else { throw LoaderInstallError.invalidMetadata }
        let root = URL(fileURLWithPath: NSString(string: gameDirectory).expandingTildeInPath)
        let versionDir = root.appendingPathComponent("versions/\(profileID)", isDirectory: true)
        try FileManager.default.createDirectory(at: versionDir, withIntermediateDirectories: true)
        let libraries = profile["libraries"] as? [[String: Any]] ?? []
        for (index, library) in libraries.enumerated() {
            guard let name = library["name"] as? String, let relative = Self.mavenPath(name),
                  let repository = library["url"] as? String, let url = URL(string: repository + relative) else { continue }
            status = "Downloading libraries · \(index + 1) / \(libraries.count)"
            let destination = root.appendingPathComponent("libraries/\(relative)")
            if !FileManager.default.fileExists(atPath: destination.path) {
                let (temporary, response) = try await URLSession.shared.download(from: url); try Self.validate(response)
                try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                try FileManager.default.moveItem(at: temporary, to: destination)
            }
        }
        try profileData.write(to: versionDir.appendingPathComponent("\(profileID).json"), options: .atomic)
    }

    private func installForge(gameVersion: String, gameDirectory: String, javaPath: String, neo: Bool) async throws {
        if neo && gameVersion == "1.20.1" { throw LoaderInstallError.neoForgeUnavailable1201 }
        let metadataURL = URL(string: neo
            ? "https://maven.neoforged.net/releases/net/neoforged/neoforge/maven-metadata.xml"
            : "https://maven.minecraftforge.net/net/minecraftforge/forge/maven-metadata.xml")!
        let (data, response) = try await URLSession.shared.data(from: metadataURL); try Self.validate(response)
        guard let xml = String(data: data, encoding: .utf8) else { throw LoaderInstallError.invalidMetadata }
        let matchPrefix = neo ? Self.neoForgePrefix(for: gameVersion) : gameVersion + "-"
        let pattern = "<version>(\(NSRegularExpression.escapedPattern(for: matchPrefix))[^<]+)</version>"
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(xml.startIndex..., in: xml)
        let versions = regex.matches(in: xml, range: range).compactMap { match -> String? in
            guard let value = Range(match.range(at: 1), in: xml) else { return nil }; return String(xml[value])
        }
        guard let fullVersion = versions.max(by: { Self.numericVersion($0).lexicographicallyPrecedes(Self.numericVersion($1)) }) else { throw LoaderInstallError.noCompatibleVersion }
        let installerAddress = neo
            ? "https://maven.neoforged.net/releases/net/neoforged/neoforge/\(fullVersion)/neoforge-\(fullVersion)-installer.jar"
            : "https://maven.minecraftforge.net/net/minecraftforge/forge/\(fullVersion)/forge-\(fullVersion)-installer.jar"
        guard let installerURL = URL(string: installerAddress) else { throw LoaderInstallError.invalidMetadata }
        status = "Downloading \(neo ? "NeoForge" : "Forge") \(fullVersion)"
        let (temporary, installerResponse) = try await URLSession.shared.download(from: installerURL); try Self.validate(installerResponse)
        let installer = FileManager.default.temporaryDirectory.appendingPathComponent("miore-forge-\(UUID().uuidString).jar")
        try FileManager.default.moveItem(at: temporary, to: installer)
        defer { try? FileManager.default.removeItem(at: installer) }
        status = "Running the official \(neo ? "NeoForge" : "Forge") installer"
        try await runJavaInstaller(
            javaPath: javaPath,
            arguments: ["-jar", installer.path, "--installClient", NSString(string: gameDirectory).expandingTildeInPath]
        )
    }

    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
    }

    nonisolated static func neoForgePrefix(for gameVersion: String) -> String {
        let parts = gameVersion.split(separator: ".").compactMap { Int($0) }
        guard parts.first == 1, parts.count >= 2 else { return gameVersion + "." }
        let minor = parts[1]
        let patch = parts.count >= 3 ? parts[2] : 0
        return "\(minor).\(patch)."
    }

    static func mavenPath(_ name: String) -> String? {
        let components = name.split(separator: ":").map(String.init)
        guard components.count >= 3 else { return nil }
        let group = components[0].replacingOccurrences(of: ".", with: "/"), artifact = components[1], version = components[2]
        let classifier = components.count > 3 ? "-\(components[3])" : ""
        return "\(group)/\(artifact)/\(version)/\(artifact)-\(version)\(classifier).jar"
    }

    private static func numericVersion(_ value: String) -> [Int] {
        value.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
    }
}
