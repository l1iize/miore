import Foundation

enum InstanceScanner {
    static func scan(gameDirectory: String) -> [GameInstance] {
        let root = URL(fileURLWithPath: NSString(string: gameDirectory).expandingTildeInPath)
        let versions = root.appendingPathComponent("versions", isDirectory: true)
        let fm = FileManager.default
        guard let directories = try? fm.contentsOfDirectory(
            at: versions,
            includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return directories.compactMap { directory in
            let id = directory.lastPathComponent
            let jsonURL = directory.appendingPathComponent("\(id).json")
            guard fm.fileExists(atPath: jsonURL.path),
                  let data = try? Data(contentsOf: jsonURL),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
            let inherited = json["inheritsFrom"] as? String
            let gameVersion = inherited ?? (json["id"] as? String ?? id)
            let values = try? directory.resourceValues(forKeys: [.contentModificationDateKey])
            return GameInstance(
                id: id,
                name: displayName(id),
                versionDirectory: directory,
                gameVersion: gameVersion,
                loader: LoaderKind.detect(versionID: id, json: json),
                modifiedAt: values?.contentModificationDate ?? .distantPast
            )
        }.sorted { lhs, rhs in
            if lhs.loader == .vanilla && rhs.loader != .vanilla { return false }
            if lhs.loader != .vanilla && rhs.loader == .vanilla { return true }
            return lhs.modifiedAt > rhs.modifiedAt
        }
    }

    private static func displayName(_ id: String) -> String {
        id.replacingOccurrences(of: "-", with: " · ").replacingOccurrences(of: "_", with: " · ")
    }
}
