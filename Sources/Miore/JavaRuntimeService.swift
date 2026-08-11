import Foundation
import Darwin

struct JavaRuntime: Identifiable, Hashable {
    let path: String
    let version: String
    let major: Int
    let source: String
    var id: String { path }
    var label: String { "Java \(major) · \(source)" }
}

@MainActor
final class JavaRuntimeService: ObservableObject {
    @Published private(set) var runtimes: [JavaRuntime] = []
    @Published private(set) var scanning = false
    @Published private(set) var lastScan: Date?

    func scan(completion: (() -> Void)? = nil) {
        guard !scanning else { return }
        scanning = true
        Task {
            let found = await Task.detached(priority: .userInitiated) { Self.discover() }.value
            runtimes = found.sorted { lhs, rhs in lhs.major == rhs.major ? lhs.source < rhs.source : lhs.major > rhs.major }
            scanning = false; lastScan = Date(); completion?()
        }
    }

    func recommended(for gameVersion: String?) -> JavaRuntime? {
        let required = Self.requiredMajor(for: gameVersion)
        let exact = runtimes.filter { $0.major == required }
        if !exact.isEmpty { return exact.min(by: { Self.preference($0) < Self.preference($1) }) }
        let newer = runtimes.filter { $0.major > required }
        if let closestMajor = newer.map(\.major).min() {
            return newer.filter { $0.major == closestMajor }.min(by: { Self.preference($0) < Self.preference($1) })
        }
        return runtimes.max(by: { $0.major < $1.major })
    }

    nonisolated static func requiredMajor(for gameVersion: String?) -> Int {
        guard let gameVersion else { return 17 }
        let numbers = gameVersion.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        guard let first = numbers.first else { return 17 }
        if first >= 26 { return 21 }
        guard first == 1, numbers.count > 1 else { return 21 }
        let minor = numbers[1], patch = numbers.count > 2 ? numbers[2] : 0
        if minor > 20 || (minor == 20 && patch >= 5) { return 21 }
        if minor >= 18 { return 17 }
        if minor == 17 { return 16 }
        return 8
    }

    private nonisolated static func discover() -> [JavaRuntime] {
        var candidates = Set<String>()
        candidates.formUnion(javaHomeCandidates())
        let home = URL(fileURLWithPath: NSHomeDirectory())
        for root in [
            URL(fileURLWithPath: "/Library/Java/JavaVirtualMachines"),
            home.appendingPathComponent("Library/Java/JavaVirtualMachines")
        ] {
            for directory in (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? [] {
                candidates.insert(directory.appendingPathComponent("Contents/Home/bin/java").path)
            }
        }
        let minecraftRuntime = home.appendingPathComponent("Library/Application Support/minecraft/runtime")
        if let enumerator = FileManager.default.enumerator(at: minecraftRuntime, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
            for case let file as URL in enumerator where file.lastPathComponent == "java" && file.path.hasSuffix("/bin/java") { candidates.insert(file.path) }
        }
        for root in [URL(fileURLWithPath: "/opt/homebrew/opt"), URL(fileURLWithPath: "/usr/local/opt")] {
            for directory in (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? [] where directory.lastPathComponent.contains("openjdk") {
                candidates.insert(directory.appendingPathComponent("bin/java").path)
                candidates.insert(directory.appendingPathComponent("libexec/openjdk.jdk/Contents/Home/bin/java").path)
            }
        }
        candidates.insert("/usr/bin/java")
        var seen = Set<String>()
        return candidates.compactMap { path in
            let resolved = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
            guard seen.insert(resolved).inserted, FileManager.default.isExecutableFile(atPath: path), let version = inspect(path) else { return nil }
            return JavaRuntime(path: path, version: version.text, major: version.major, source: sourceName(path))
        }
    }

    private nonisolated static func javaHomeCandidates() -> Set<String> {
        let process = Process(); let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/libexec/java_home"); process.arguments = ["-V"]
        process.standardOutput = pipe; process.standardError = pipe
        guard (try? process.run()) != nil else { return [] }
        guard waitForExit(process, timeout: 5) else { return [] }
        let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        guard let regex = try? NSRegularExpression(pattern: #"(/[^\n]+/Contents/Home)"#) else { return [] }
        let range = NSRange(output.startIndex..., in: output)
        return Set(regex.matches(in: output, range: range).compactMap { match in
            guard let value = Range(match.range(at: 1), in: output) else { return nil }
            return String(output[value]).trimmingCharacters(in: .whitespaces).appending("/bin/java")
        })
    }

    private nonisolated static func inspect(_ path: String) -> (text: String, major: Int)? {
        let process = Process(); let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: path); process.arguments = ["-version"]
        process.standardOutput = pipe; process.standardError = pipe
        guard (try? process.run()) != nil else { return nil }
        guard waitForExit(process, timeout: 5) else { return nil }
        guard process.terminationStatus == 0 else { return nil }
        let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        guard let regex = try? NSRegularExpression(pattern: #"version\s+\"([^\"]+)\""#),
              let match = regex.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)),
              let value = Range(match.range(at: 1), in: output) else { return nil }
        let version = String(output[value]); let components = version.split(separator: ".")
        let major = components.first == "1" && components.count > 1 ? Int(components[1]) : Int(components.first ?? "")
        guard let major else { return nil }; return (version, major)
    }

    private nonisolated static func waitForExit(_ process: Process, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning, Date() < deadline { Thread.sleep(forTimeInterval: 0.05) }
        guard process.isRunning else { return true }
        process.terminate()
        Thread.sleep(forTimeInterval: 0.2)
        if process.isRunning { Darwin.kill(process.processIdentifier, SIGKILL) }
        return false
    }

    private nonisolated static func sourceName(_ path: String) -> String {
        if path.contains("/minecraft/runtime/") { return "Minecraft Runtime" }
        if path.contains("Homebrew") || path.contains("/homebrew/") || path.contains("/usr/local/opt/") { return "Homebrew" }
        let components = URL(fileURLWithPath: path).pathComponents
        if let index = components.firstIndex(of: "JavaVirtualMachines"), components.indices.contains(index + 1) { return components[index + 1] }
        return URL(fileURLWithPath: path).deletingLastPathComponent().deletingLastPathComponent().lastPathComponent
    }

    private nonisolated static func preference(_ runtime: JavaRuntime) -> Int {
        if runtime.source == "Minecraft Runtime" { return 0 }
        if runtime.path != "/usr/bin/java" { return 1 }
        return 2
    }
}
