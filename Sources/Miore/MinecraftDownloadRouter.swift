import Foundation

/// Selects the faster Minecraft download origin once per app session and
/// automatically falls back to the other origin when a request fails.
actor MinecraftDownloadRouter {
    static let shared = MinecraftDownloadRouter()

    private var prefersMirror: Bool?

    func downloadCandidates(for originalURL: URL) async -> [URL] {
        await orderedCandidates(for: originalURL)
    }

    nonisolated static func manifestURLCandidates() -> [URL] {
        [
            URL(string: "https://piston-meta.mojang.com/mc/game/version_manifest_v2.json")!,
            URL(string: "https://bmclapi2.bangbang93.com/mc/game/version_manifest_v2.json")!
        ]
    }

    func data(from originalURL: URL) async throws -> Data {
        let candidates = await orderedCandidates(for: originalURL)
        var lastError: Error = URLError(.badServerResponse)
        for url in candidates {
            do {
                var request = URLRequest(url: url, timeoutInterval: 30)
                request.cachePolicy = .reloadRevalidatingCacheData
                let (data, response) = try await URLSession.shared.data(for: request)
                try Self.validate(response)
                return data
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    func download(from originalURL: URL) async throws -> URL {
        let candidates = await orderedCandidates(for: originalURL)
        var lastError: Error = URLError(.badServerResponse)
        for url in candidates {
            do {
                var request = URLRequest(url: url, timeoutInterval: 90)
                request.cachePolicy = .reloadIgnoringLocalCacheData
                let (temporary, response) = try await URLSession.shared.download(for: request)
                try Self.validate(response)
                return temporary
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    private func orderedCandidates(for url: URL) async -> [URL] {
        guard let mirror = Self.mirrorURL(for: url), mirror != url else { return [url] }
        let mirrorFirst = await shouldPreferMirror()
        return mirrorFirst ? [mirror, url] : [url, mirror]
    }

    private func shouldPreferMirror() async -> Bool {
        if let prefersMirror { return prefersMirror }
        let official = URL(string: "https://piston-meta.mojang.com/mc/game/version_manifest_v2.json")!
        let mirror = URL(string: "https://bmclapi2.bangbang93.com/mc/game/version_manifest_v2.json")!
        async let officialLatency = Self.probe(official)
        async let mirrorLatency = Self.probe(mirror)
        let result = await (officialLatency, mirrorLatency)
        let useMirror = result.1 < result.0
        prefersMirror = useMirror
        return useMirror
    }

    private static func probe(_ url: URL) async -> TimeInterval {
        let start = Date()
        do {
            var request = URLRequest(url: url, timeoutInterval: 6)
            request.httpMethod = "HEAD"
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (_, response) = try await URLSession.shared.data(for: request)
            try validate(response)
            return Date().timeIntervalSince(start)
        } catch {
            return .greatestFiniteMagnitude
        }
    }

    nonisolated static func mirrorURL(for url: URL) -> URL? {
        guard let host = url.host?.lowercased() else { return nil }
        let path = url.path
        let replacement: String
        switch host {
        case "piston-meta.mojang.com", "piston-data.mojang.com", "launchermeta.mojang.com", "launcher.mojang.com":
            replacement = "https://bmclapi2.bangbang93.com\(path)"
        case "libraries.minecraft.net":
            replacement = "https://bmclapi2.bangbang93.com/maven\(path)"
        case "resources.download.minecraft.net":
            replacement = "https://bmclapi2.bangbang93.com/assets\(path)"
        default:
            return nil
        }
        return URL(string: replacement)
    }

    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}
