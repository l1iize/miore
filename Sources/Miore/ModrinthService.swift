import Foundation
import CryptoKit

enum ContentKind: String, CaseIterable, Identifiable {
    case mod = "mod"
    case resourcepack = "resourcepack"
    case modpack = "modpack"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .mod: return L10n.t("content.mod")
        case .resourcepack: return L10n.t("content.resourcepack")
        case .modpack: return L10n.t("content.modpack")
        }
    }
    var apiValue: String {
        switch self { case .mod: return "mod"; case .resourcepack: return "resourcepack"; case .modpack: return "modpack" }
    }
    var destination: String {
        switch self { case .mod: return "mods"; case .resourcepack: return "resourcepacks"; case .modpack: return "" }
    }
}

struct ModrinthProject: Codable, Identifiable, Equatable {
    let projectID: String
    let slug: String
    let title: String
    let description: String
    let author: String
    let downloads: Int
    let projectType: String
    var id: String { projectID }
    enum CodingKeys: String, CodingKey {
        case projectID = "project_id", slug, title, description, author, downloads
        case projectType = "project_type"
    }
}

private struct SearchResponse: Codable { let hits: [ModrinthProject] }
private struct ModrinthVersion: Codable {
    let id: String
    let projectID: String
    let versionNumber: String
    let files: [ModrinthFile]
    let dependencies: [ModrinthDependency]
    enum CodingKeys: String, CodingKey {
        case id, files, dependencies
        case projectID = "project_id"
        case versionNumber = "version_number"
    }
}
private struct ModrinthFile: Codable {
    let hashes: [String: String]
    let url: URL
    let filename: String
    let primary: Bool
}
struct ModpackInstallPlan: Equatable {
    let loader: InstallableLoader
    let gameVersion: String
}

private struct ModrinthDependency: Codable {
    let versionID: String?
    let projectID: String?
    let dependencyType: String
    enum CodingKeys: String, CodingKey {
        case versionID = "version_id"
        case projectID = "project_id"
        case dependencyType = "dependency_type"
    }
}

enum ModrinthError: LocalizedError {
    case invalidResponse, noCompatibleVersion, incompatibleMinecraftVersion(required: String, selected: String), unsafePath(String), badHash(String), installFailed(String)
    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Modrinth returned an invalid response."
        case .noCompatibleVersion: return "No compatible file was found for this game version and loader."
        case .incompatibleMinecraftVersion(let required, let selected): return "This modpack requires Minecraft \(required), but the selected instance uses \(selected). Select or install the matching vanilla version first."
        case .unsafePath(let path): return "The modpack contains an unsafe path: \(path)"
        case .badHash(let file): return "Download verification failed: \(file)"
        case .installFailed(let value): return value
        }
    }
}

@MainActor
final class ModrinthService: ObservableObject {
    @Published private(set) var results: [ModrinthProject] = []
    @Published private(set) var searching = false
    @Published private(set) var installingProjectID: String?
    @Published private(set) var status = ""
    @Published var error: String?
    private let decoder = JSONDecoder()
    private var searchTask: Task<Void, Never>?
    private var searchGeneration = 0

    func search(query: String, kind: ContentKind, gameVersion: String?, loader: LoaderKind?) {
        searchGeneration += 1
        let generation = searchGeneration
        searchTask?.cancel()
        searching = true; error = nil
        searchTask = Task {
            do {
                var facets = [["project_type:\(kind.apiValue)"]]
                if let gameVersion, !gameVersion.isEmpty { facets.append(["versions:\(gameVersion)"]) }
                if kind == .mod, let loader, loader != .vanilla { facets.append(["categories:\(loader.rawValue.lowercased())"]) }
                let facetsData = try JSONSerialization.data(withJSONObject: facets)
                var components = URLComponents(string: "https://api.modrinth.com/v2/search")!
                components.queryItems = [URLQueryItem(name: "query", value: query), URLQueryItem(name: "limit", value: "40"),
                                         URLQueryItem(name: "index", value: query.isEmpty ? "downloads" : "relevance"),
                                         URLQueryItem(name: "facets", value: String(decoding: facetsData, as: UTF8.self))]
                let data = try await request(components.url!)
                try Task.checkCancellation()
                guard generation == searchGeneration else { return }
                results = try Self.decodeSearchResults(data)
                searching = false
            } catch is CancellationError {
                guard generation == searchGeneration else { return }
                searching = false
            } catch {
                guard generation == searchGeneration else { return }
                self.error = error.localizedDescription; searching = false
            }
        }
    }

    func install(project: ModrinthProject, kind: ContentKind, gameVersion: String?, loader: LoaderKind?, gameDirectory: String, completion: @escaping (ModpackInstallPlan?) -> Void) {
        guard installingProjectID == nil else { return }
        guard let gameVersion else { error = "Please choose a Minecraft instance first."; return }
        installingProjectID = project.id; status = "Finding a compatible version"; error = nil
        Task {
            do {
                let versions = try await fetchVersions(projectID: project.id, gameVersion: gameVersion, loader: loader, kind: kind)
                guard let version = versions.first, let file = version.files.first(where: \.primary) ?? version.files.first else { throw ModrinthError.noCompatibleVersion }
                let root = URL(fileURLWithPath: NSString(string: gameDirectory).expandingTildeInPath)
                var modpackPlan: ModpackInstallPlan?
                if kind == .modpack {
                    status = "Installing modpack \(version.versionNumber)"
                    modpackPlan = try await installModpack(file: file, root: root, selectedGameVersion: gameVersion)
                } else {
                    status = "Downloading \(file.filename)"
                    let destination = try safeContentDestination(root: root, folder: kind.destination, filename: file.filename)
                    try await download(file: file, destination: destination)
                    if kind == .mod { try await installRequiredDependencies(version.dependencies, root: root, gameVersion: gameVersion, loader: loader) }
                }
                status = "All done ♡"; installingProjectID = nil; completion(modpackPlan)
            } catch {
                self.error = error.localizedDescription; self.status = "Installation failed"; self.installingProjectID = nil
            }
        }
    }

    private func fetchVersions(projectID: String, gameVersion: String, loader: LoaderKind?, kind: ContentKind) async throws -> [ModrinthVersion] {
        var components = URLComponents(string: "https://api.modrinth.com/v2/project/\(projectID)/version")!
        components.queryItems = [URLQueryItem(name: "game_versions", value: jsonArray([gameVersion]))]
        if kind == .mod, let loader, loader != .vanilla { components.queryItems?.append(URLQueryItem(name: "loaders", value: jsonArray([loader.rawValue.lowercased()]))) }
        if kind == .resourcepack { components.queryItems?.append(URLQueryItem(name: "loaders", value: jsonArray(["minecraft"]))) }
        return try decoder.decode([ModrinthVersion].self, from: await request(components.url!))
    }

    private func installRequiredDependencies(_ dependencies: [ModrinthDependency], root: URL, gameVersion: String, loader: LoaderKind?) async throws {
        for dependency in dependencies where dependency.dependencyType == "required" {
            let version: ModrinthVersion?
            if let id = dependency.versionID {
                version = try decoder.decode(ModrinthVersion.self, from: await request(URL(string: "https://api.modrinth.com/v2/version/\(id)")!))
            } else if let projectID = dependency.projectID {
                version = try await fetchVersions(projectID: projectID, gameVersion: gameVersion, loader: loader, kind: .mod).first
            } else { version = nil }
            guard let version, let file = version.files.first(where: \.primary) ?? version.files.first else { continue }
            status = "Installing dependency · \(file.filename)"
            let destination = try safeContentDestination(root: root, folder: "mods", filename: file.filename)
            try await download(file: file, destination: destination)
        }
    }

    private func installModpack(file: ModrinthFile, root: URL, selectedGameVersion: String) async throws -> ModpackInstallPlan? {
        let temporaryRoot = FileManager.default.temporaryDirectory.appendingPathComponent("miore-mrpack-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryRoot) }
        let archive = temporaryRoot.appendingPathComponent("pack.mrpack")
        try await download(file: file, destination: archive)
        let extracted = temporaryRoot.appendingPathComponent("extracted", isDirectory: true)
        try FileManager.default.createDirectory(at: extracted, withIntermediateDirectories: true)
        let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto"); process.arguments = ["-x", "-k", archive.path, extracted.path]
        try process.run()
        let terminationStatus = await Task.detached(priority: .userInitiated) {
            process.waitUntilExit()
            return process.terminationStatus
        }.value
        guard terminationStatus == 0 else { throw ModrinthError.installFailed("Mio could not unpack the modpack.") }
        let indexURL = extracted.appendingPathComponent("modrinth.index.json")
        guard let data = try? Data(contentsOf: indexURL), let index = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let files = index["files"] as? [[String: Any]] else { throw ModrinthError.invalidResponse }
        let dependencies = index["dependencies"] as? [String: String] ?? [:]
        let modpackPlan = try Self.modpackPlan(dependencies: dependencies, selectedGameVersion: selectedGameVersion)
        for (position, item) in files.enumerated() {
            guard let path = item["path"] as? String, let downloads = item["downloads"] as? [String],
                  let first = downloads.first, let url = URL(string: first) else { continue }
            let destination = try safeDestination(root: root, relative: path)
            status = "Installing modpack files · \(position + 1) / \(files.count)"
            let hashes = item["hashes"] as? [String: String] ?? [:]
            try await download(url: url, hashes: hashes, destination: destination)
        }
        for folder in ["overrides", "client-overrides"] {
            let source = extracted.appendingPathComponent(folder, isDirectory: true)
            if FileManager.default.fileExists(atPath: source.path) { try copySafeContents(from: source, to: root) }
        }
        return modpackPlan
    }

    nonisolated static func modpackPlan(dependencies: [String: String], selectedGameVersion: String) throws -> ModpackInstallPlan? {
        guard let requiredGameVersion = dependencies["minecraft"], !requiredGameVersion.isEmpty else { throw ModrinthError.invalidResponse }
        guard requiredGameVersion == selectedGameVersion else {
            throw ModrinthError.incompatibleMinecraftVersion(required: requiredGameVersion, selected: selectedGameVersion)
        }
        if dependencies["fabric-loader"] != nil { return ModpackInstallPlan(loader: .fabric, gameVersion: requiredGameVersion) }
        if dependencies["quilt-loader"] != nil { return ModpackInstallPlan(loader: .quilt, gameVersion: requiredGameVersion) }
        if dependencies["forge"] != nil { return ModpackInstallPlan(loader: .forge, gameVersion: requiredGameVersion) }
        if dependencies["neoforge"] != nil { return ModpackInstallPlan(loader: .neoForge, gameVersion: requiredGameVersion) }
        return nil
    }

    private func download(file: ModrinthFile, destination: URL) async throws {
        try await download(url: file.url, hashes: file.hashes, destination: destination)
    }

    private func download(url: URL, hashes: [String: String], destination: URL) async throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: destination.path), Self.matches(destination, hashes: hashes) { return }
        let (temporary, response) = try await URLSession.shared.download(from: url); try Self.validate(response)
        guard Self.matches(temporary, hashes: hashes) else {
            try? fm.removeItem(at: temporary)
            throw ModrinthError.badHash(destination.lastPathComponent)
        }
        try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fm.fileExists(atPath: destination.path) {
            _ = try fm.replaceItemAt(destination, withItemAt: temporary)
        } else {
            try fm.moveItem(at: temporary, to: destination)
        }
    }

    private func request(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url); request.setValue("Miore/0.2 (dev.miore.launcher)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request); try Self.validate(response); return data
    }

    private func safeDestination(root: URL, relative: String) throws -> URL {
        let cleanRoot = root.standardizedFileURL.path
        let destination = root.appendingPathComponent(relative).standardizedFileURL
        guard destination.path.hasPrefix(cleanRoot + "/") else { throw ModrinthError.unsafePath(relative) }
        return destination
    }

    nonisolated static func validatedContentFilename(_ filename: String) throws -> String {
        guard !filename.isEmpty,
              filename != ".", filename != "..",
              !filename.contains("/"), !filename.contains("\\"), !filename.contains("\0") else {
            throw ModrinthError.unsafePath(filename)
        }
        return filename
    }

    private func safeContentDestination(root: URL, folder: String, filename: String) throws -> URL {
        let safeFilename = try Self.validatedContentFilename(filename)
        return try safeDestination(root: root, relative: "\(folder)/\(safeFilename)")
    }

    private func copySafeContents(from source: URL, to root: URL) throws {
        guard let enumerator = FileManager.default.enumerator(at: source, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else { return }
        for case let file as URL in enumerator {
            let values = try file.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]); if values.isSymbolicLink == true { continue }
            let relative = String(file.path.dropFirst(source.path.count + 1)); let destination = try safeDestination(root: root, relative: relative)
            if values.isDirectory == true { try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true) }
            else {
                try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                if FileManager.default.fileExists(atPath: destination.path) { try FileManager.default.removeItem(at: destination) }
                try FileManager.default.copyItem(at: file, to: destination)
            }
        }
    }

    private static func matches(_ url: URL, hashes: [String: String]) -> Bool {
        guard !hashes.isEmpty, let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return hashes.isEmpty }
        if let expected = hashes["sha512"] { return SHA512.hash(data: data).map { String(format: "%02x", $0) }.joined() == expected }
        if let expected = hashes["sha1"] { return Insecure.SHA1.hash(data: data).map { String(format: "%02x", $0) }.joined() == expected }
        return true
    }

    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
    }

    private func jsonArray(_ values: [String]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: values),
              let value = String(data: data, encoding: .utf8) else { return "[]" }
        return value
    }

    nonisolated static func decodeSearchResults(_ data: Data) throws -> [ModrinthProject] {
        try JSONDecoder().decode(SearchResponse.self, from: data).hits
    }
}
