import Foundation

/// A tiny JSON-backed config home for Miore's settings and session data. ♡
final class LocalConfigStore: @unchecked Sendable {
    static let shared = LocalConfigStore()

    private let lock = NSLock()
    private let fileURL: URL
    private var values: [String: Any] = [:]

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = base.appendingPathComponent("Miore", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: folder,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: folder.path)
        fileURL = folder.appendingPathComponent("config.json")
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
        if let data = try? Data(contentsOf: fileURL),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            values = object
        }
    }

    func string(forKey key: String) -> String? { value(forKey: key) as? String }
    func double(forKey key: String) -> Double? { (value(forKey: key) as? NSNumber)?.doubleValue }
    func bool(forKey key: String) -> Bool? { (value(forKey: key) as? NSNumber)?.boolValue }

    func set(_ value: Any, forKey key: String) {
        lock.lock()
        values[key] = value
        saveLocked()
        lock.unlock()
    }

    func removeObject(forKey key: String) {
        lock.lock()
        values.removeValue(forKey: key)
        saveLocked()
        lock.unlock()
    }

    private func value(forKey key: String) -> Any? {
        lock.lock(); defer { lock.unlock() }
        return values[key]
    }

    private func saveLocked() {
        guard JSONSerialization.isValidJSONObject(values),
              let data = try? JSONSerialization.data(withJSONObject: values, options: [.prettyPrinted, .sortedKeys]) else { return }
        try? data.write(to: fileURL, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }
}
