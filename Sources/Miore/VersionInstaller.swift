import Foundation
import CryptoKit

struct RemoteVersion: Identifiable, Codable, Hashable {
    let id: String
    let type: String
    let url: URL
    let releaseTime: Date
}

private struct VersionManifest: Codable {
    let versions: [RemoteVersion]
}

enum InstallError: LocalizedError {
    case badManifest, invalidMetadata, missingDownload(String), checksum(String)
    var errorDescription: String? {
        switch self {
        case .badManifest: return "Mio could not read the Mojang version manifest."
        case .invalidMetadata: return "The version metadata is invalid."
        case .missingDownload(let name): return "Version metadata is missing a download: \(name)"
        case .checksum(let path): return "File verification failed: \(path)"
        }
    }
}

@MainActor
final class VersionInstaller: ObservableObject {
    @Published private(set) var versions: [RemoteVersion] = []
    @Published private(set) var loadingManifest = false
    @Published private(set) var installingID: String?
    @Published private(set) var progress: Double = 0
    @Published private(set) var status = ""
    @Published var error: String?

    func loadManifest() {
        guard !loadingManifest else { return }
        loadingManifest = true; error = nil
        Task {
            do {
                let url = URL(string: "https://piston-meta.mojang.com/mc/game/version_manifest_v2.json")!
                let (data, response) = try await URLSession.shared.data(from: url)
                try Self.validate(response)
                versions = try Self.decodeManifest(data)
                loadingManifest = false
            } catch {
                self.error = error.localizedDescription; loadingManifest = false
            }
        }
    }

    func install(_ version: RemoteVersion, gameDirectory: String, completion: @escaping () -> Void) {
        guard installingID == nil else { return }
        installingID = version.id; progress = 0; status = "Reading version metadata"; error = nil
        Task {
            let root = URL(fileURLWithPath: NSString(string: gameDirectory).expandingTildeInPath)
            let versionDir = root.appendingPathComponent("versions/\(version.id)", isDirectory: true)
            let versionExisted = FileManager.default.fileExists(atPath: versionDir.path)
            do {
                try FileManager.default.createDirectory(at: versionDir, withIntermediateDirectories: true)
                let (metadata, response) = try await URLSession.shared.data(from: version.url)
                try Self.validate(response)
                guard let json = try JSONSerialization.jsonObject(with: metadata) as? [String: Any] else { throw InstallError.invalidMetadata }
                try metadata.write(to: versionDir.appendingPathComponent("\(version.id).json"), options: .atomic)

                status = "Downloading the game"; progress = 0.05
                guard let client = (json["downloads"] as? [String: Any])?["client"] as? [String: Any] else { throw InstallError.missingDownload("client") }
                try await download(record: client, to: versionDir.appendingPathComponent("\(version.id).jar"))

                let libraryRecords = Self.libraryDownloads(json)
                status = "Downloading libraries · 0 / \(libraryRecords.count)"
                for (index, item) in libraryRecords.enumerated() {
                    try await download(record: item.record, to: root.appendingPathComponent("libraries/\(item.path)"))
                    progress = 0.08 + 0.32 * Double(index + 1) / Double(max(libraryRecords.count, 1))
                    status = "Downloading libraries · \(index + 1) / \(libraryRecords.count)"
                }

                if let assetIndex = json["assetIndex"] as? [String: Any],
                   let assetID = assetIndex["id"] as? String {
                    status = "Reading the asset index"; progress = 0.42
                    let indexURL = root.appendingPathComponent("assets/indexes/\(assetID).json")
                    try await download(record: assetIndex, to: indexURL)
                    let indexData = try Data(contentsOf: indexURL)
                    guard let indexJSON = try JSONSerialization.jsonObject(with: indexData) as? [String: Any],
                          let objects = indexJSON["objects"] as? [String: [String: Any]] else { throw InstallError.invalidMetadata }
                    let unique = Dictionary(grouping: objects.values, by: { $0["hash"] as? String ?? UUID().uuidString }).compactMap { $0.value.first }
                    status = "Downloading assets · 0 / \(unique.count)"
                    for (index, object) in unique.enumerated() {
                        guard let hash = object["hash"] as? String else { continue }
                        let relative = "\(hash.prefix(2))/\(hash)"
                        let url = "https://resources.download.minecraft.net/\(relative)"
                        try await download(record: ["url": url, "sha1": hash], to: root.appendingPathComponent("assets/objects/\(relative)"))
                        progress = 0.42 + 0.56 * Double(index + 1) / Double(max(unique.count, 1))
                        if index % 20 == 0 { status = "Downloading assets · \(index + 1) / \(unique.count)" }
                    }
                }
                status = "All done ♡"; progress = 1
                installingID = nil
                completion()
            } catch {
                if !versionExisted { try? FileManager.default.removeItem(at: versionDir) }
                self.error = error.localizedDescription; self.status = "Installation failed"; self.installingID = nil
            }
        }
    }

    private func download(record: [String: Any], to destination: URL) async throws {
        let fm = FileManager.default
        let expected = record["sha1"] as? String
        if fm.fileExists(atPath: destination.path), expected == nil || Self.sha1(destination) == expected { return }
        guard let address = record["url"] as? String, let url = URL(string: address) else { throw InstallError.missingDownload(destination.lastPathComponent) }
        let (temporary, response) = try await URLSession.shared.download(from: url)
        try Self.validate(response)
        try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }
        try fm.moveItem(at: temporary, to: destination)
        if let expected, Self.sha1(destination) != expected {
            try? fm.removeItem(at: destination)
            throw InstallError.checksum(destination.path)
        }
    }

    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
    }

    private static func sha1(_ url: URL) -> String? {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }
        return Insecure.SHA1.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func libraryDownloads(_ json: [String: Any]) -> [(path: String, record: [String: Any])] {
        var result: [(path: String, record: [String: Any])] = []
        for library in json["libraries"] as? [[String: Any]] ?? [] {
            guard let downloads = library["downloads"] as? [String: Any] else { continue }
            if let artifact = downloads["artifact"] as? [String: Any], let path = artifact["path"] as? String { result.append((path, artifact)) }
            if let natives = library["natives"] as? [String: String],
               let classifierTemplate = natives["osx"],
               let classifiers = downloads["classifiers"] as? [String: Any] {
                for classifier in NativeClassifier.candidates(template: classifierTemplate) {
                    if let record = classifiers[classifier] as? [String: Any], let path = record["path"] as? String { result.append((path, record)); break }
                }
            }
        }
        var seen = Set<String>()
        return result.filter { seen.insert($0.path).inserted }
    }

    nonisolated static func decodeManifest(_ data: Data) throws -> [RemoteVersion] {
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(VersionManifest.self, from: data).versions
    }
}
