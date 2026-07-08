import Foundation

/// Downloads the completion spec pack at runtime and installs it to
/// ~/.local/share/tine/specs — so specs update without an app release. The pack
/// is built + published by the tinecli/autocomplete fork; the app's own
/// built-in specs (builtin-specs/, e.g. the `tine` CLI) are merged in on top.
@MainActor
final class SpecInstaller: ObservableObject {
    enum Status: Equatable {
        case idle, running, done(String), failed(String)
    }
    @Published var status: Status = .idle

    /// Pinned HTTPS release asset — same trust root as the notarized app. Never
    /// make this a user-configurable host.
    nonisolated static let packURL = URL(string:
        "https://github.com/tinecli/autocomplete/releases/download/specs/specs.tar.gz")!
    nonisolated static let specsDir = "\(NSHomeDirectory())/.local/share/tine/specs"

    /// Called after a successful install (main thread) so the app can refresh.
    var onInstalled: (() -> Void)?

    /// True once at least one spec tile is present.
    nonisolated static func isInstalled() -> Bool {
        (try? FileManager.default.contentsOfDirectory(atPath: specsDir))?
            .contains { $0.hasSuffix(".js") } ?? false
    }

    /// Distinct CLIs covered by the pack — unique top-level entries (one `foo.js`
    /// or one `foo/` directory each), NOT index.json entries (which list one per
    /// spec *file*; `aws` alone fragments into hundreds).
    nonisolated static func installedCount() -> Int {
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: specsDir) else { return 0 }
        var clis = Set<String>()
        for e in entries {
            if e.hasSuffix(".js") {
                clis.insert(String(e.dropLast(3)))
            } else {
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: "\(specsDir)/\(e)", isDirectory: &isDir), isDir.boolValue {
                    clis.insert(e)
                }
            }
        }
        return clis.count
    }

    func install() {
        guard status != .running else { return }
        status = .running
        Task {
            do {
                let count = try await Self.downloadAndInstall()
                self.status = .done("\(count) commands")
                self.onInstalled?()
            } catch {
                self.status = .failed(error.localizedDescription)
            }
        }
    }

    nonisolated private static func downloadAndInstall() async throws -> Int {
        let fm = FileManager.default
        let (tmp, resp) = try await URLSession.shared.download(from: packURL)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw NSError(domain: "tine", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "spec download failed (HTTP error)"])
        }

        let staging = NSTemporaryDirectory() + "tine-specs-\(UUID().uuidString)"
        try fm.createDirectory(atPath: staging, withIntermediateDirectories: true)
        defer { try? fm.removeItem(atPath: staging) }

        let tar = Process()
        tar.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        tar.arguments = ["-xzf", tmp.path, "-C", staging]
        try tar.run()
        tar.waitUntilExit()
        guard tar.terminationStatus == 0 else {
            throw NSError(domain: "tine", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "spec extract failed"])
        }

        mergeBuiltins(into: staging)

        // Swap into place: remove the old dir, move staging in.
        try fm.createDirectory(atPath: (specsDir as NSString).deletingLastPathComponent,
                               withIntermediateDirectories: true)
        try? fm.removeItem(atPath: specsDir)
        try fm.moveItem(atPath: staging, toPath: specsDir)
        return installedCount()
    }

    /// Copy the app's bundled built-in specs (builtin-specs/, e.g. tine.js) into
    /// the pack and register them in index.json so they resolve like pack specs.
    nonisolated private static func mergeBuiltins(into dir: String) {
        let fm = FileManager.default
        guard let res = Bundle.main.resourcePath else { return }
        let builtin = "\(res)/builtin-specs"
        guard let files = try? fm.contentsOfDirectory(atPath: builtin) else { return }

        var names: [String] = []
        for f in files where f.hasSuffix(".js") {
            try? fm.copyItem(atPath: "\(builtin)/\(f)", toPath: "\(dir)/\(f)")
            names.append(String(f.dropLast(3)))
        }
        guard !names.isEmpty else { return }

        let idxPath = "\(dir)/index.json"
        guard let data = fm.contents(atPath: idxPath),
              var obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else { return }
        var comps = (obj["completions"] as? [String]) ?? []
        for n in names where !comps.contains(n) { comps.append(n) }
        obj["completions"] = comps
        if obj["diffVersionedCompletions"] == nil { obj["diffVersionedCompletions"] = [String]() }
        if let out = try? JSONSerialization.data(withJSONObject: obj) {
            try? out.write(to: URL(fileURLWithPath: idxPath))
        }
    }
}
