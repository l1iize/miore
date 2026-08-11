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

private struct DownloadItem: Sendable {
    let url: URL
    let expectedSHA1: String?
    let destination: URL
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

    private let router = MinecraftDownloadRouter.shared
    private let parallelDownloads = 8

    func loadManifest() {
        guard !loadingManifest else { return }
        loadingManifest = true; error = nil
        Task {
            do {
                var lastError: Error = InstallError.badManifest
                for url in MinecraftDownloadRouter.manifestURLCandidates() {
                    do {
                        versions = try Self.decodeManifest(await router.data(from: url))
                        loadingManifest = false
                        return
                    } catch {
                        lastError = error
                    }
                }
                throw lastError
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
                let metadata = try await router.data(from: version.url)
                guard let json = try JSONSerialization.jsonObject(with: metadata) as? [String: Any] else { throw InstallError.invalidMetadata }
                try metadata.write(to: versionDir.appendingPathComponent("\(version.id).json"), options: .atomic)

                status = "Downloading the game"; progress = 0.05
                guard let client = (json["downloads"] as? [String: Any])?["client"] as? [String: Any] else { throw InstallError.missingDownload("client") }
                try await download(record: client, to: versionDir.appendingPathComponent("\(version.id).jar"))

                let libraryItems = try Self.libraryDownloads(json).map {
                    try Self.downloadItem(record: $0.record, destination: root.appendingPathComponent("libraries/\($0.path)"))
                }
                status = "Downloading libraries · 0 / \(libraryItems.count)"
                try await downloadConcurrently(libraryItems, progressRange: 0.08...0.40, label: "Downloading libraries")

                if let assetIndex = json["assetIndex"] as? [String: Any],
                   let assetID = assetIndex["id"] as? String {
                    status = "Reading the asset index"; progress = 0.42
                    let indexURL = root.appendingPathComponent("assets/indexes/\(assetID).json")
                    try await download(record: assetIndex, to: indexURL)
                    let indexData = try Data(contentsOf: indexURL)
                    guard let indexJSON = try JSONSerialization.jsonObject(with: indexData) as? [String: Any],
                          let objects = indexJSON["objects"] as? [String: [String: Any]] else { throw InstallError.invalidMetadata }
                    let unique = Dictionary(grouping: objects.values, by: { $0["hash"] as? String ?? UUID().uuidString }).compactMap { $0.value.first }
                    let assetItems = try unique.compactMap { object -> DownloadItem? in
                        guard let hash = object["hash"] as? String else { return nil }
                        let relative = "\(hash.prefix(2))/\(hash)"
                        guard let url = URL(string: "https://resources.download.minecraft.net/\(relative)") else { throw InstallError.invalidMetadata }
                        return DownloadItem(url: url, expectedSHA1: hash, destination: root.appendingPathComponent("assets/objects/\(relative)"))
                    }
                    status = "Downloading assets · 0 / \(assetItems.count)"
                    try await downloadConcurrently(assetItems, progressRange: 0.42...0.98, label: "Downloading assets")
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
        try await download(item: Self.downloadItem(record: record, destination: destination))
    }

    private func downloadConcurrently(_ items: [DownloadItem], progressRange: ClosedRange<Double>, label: String) async throws {
        guard !items.isEmpty else { progress = progressRange.upperBound; return }
        var iterator = items.makeIterator()
        var completed = 0
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<min(parallelDownloads, items.count) {
                if let item = iterator.next() { group.addTask { try await self.download(item: item) } }
            }
            while try await group.next() != nil {
                completed += 1
                let fraction = Double(completed) / Double(items.count)
                progress = progressRange.lowerBound + (progressRange.upperBound - progressRange.lowerBound) * fraction
                if completed == items.count || completed % 10 == 0 { status = "\(label) · \(completed) / \(items.count)" }
                if let item = iterator.next() { group.addTask { try await self.download(item: item) } }
            }
        }
    }

    private func download(item: DownloadItem) async throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: item.destination.path),
           item.expectedSHA1 == nil || Self.sha1(item.destination) == item.expectedSHA1 { return }
        var lastError: Error = URLError(.badServerResponse)
        for candidate in await router.downloadCandidates(for: item.url) {
            do {
                let temporary = try await router.download(from: candidate)
                guard item.expectedSHA1 == nil || Self.sha1(temporary) == item.expectedSHA1 else {
                    try? fm.removeItem(at: temporary)
                    throw InstallError.checksum(item.destination.path)
                }
                try fm.createDirectory(at: item.destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                if fm.fileExists(atPath: item.destination.path) {
                    _ = try fm.replaceItemAt(item.destination, withItemAt: temporary)
                } else {
                    try fm.moveItem(at: temporary, to: item.destination)
                }
                return
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    private static func downloadItem(record: [String: Any], destination: URL) throws -> DownloadItem {
        guard let address = record["url"] as? String, let url = URL(string: address) else { throw InstallError.missingDownload(destination.lastPathComponent) }
        return DownloadItem(url: url, expectedSHA1: record["sha1"] as? String, destination: destination)
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
