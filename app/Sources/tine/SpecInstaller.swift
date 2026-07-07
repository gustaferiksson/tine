import Foundation

/// Installs/updates the spec pack. Today it runs the repo's install-specs.sh
/// (dev). Once the pack is hosted (task #8), swap this for a URL download +
/// extract to ~/.local/share/tine/specs.
@MainActor
final class SpecInstaller: ObservableObject {
    enum Status: Equatable {
        case idle, running, done(String), failed(String)
    }
    @Published var status: Status = .idle

    /// Installed spec count (from the pack's index.json).
    nonisolated static func installedCount() -> Int {
        let path = "\(NSHomeDirectory())/.local/share/tine/specs/index.json"
        guard let data = FileManager.default.contents(atPath: path),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let c = obj["completions"] as? [Any] else { return 0 }
        return c.count
    }

    /// The repo root, inferred from the .app location in dev (…/tine/.build/tine.app).
    private static func repoRoot() -> String? {
        let app = Bundle.main.bundlePath as NSString                 // …/.build/tine.app
        let repo = (app.deletingLastPathComponent as NSString).deletingLastPathComponent
        return FileManager.default.fileExists(atPath: "\(repo)/scripts/install-specs.sh") ? repo : nil
    }

    func install() {
        guard status != .running else { return }
        guard let repo = Self.repoRoot() else {
            status = .failed("No spec source configured (hosting: task #8).")
            return
        }
        status = .running
        Task.detached {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/bash")
            proc.arguments = ["\(repo)/scripts/install-specs.sh"]
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = pipe
            do {
                try proc.run()
                proc.waitUntilExit()
                let ok = proc.terminationStatus == 0
                let count = SpecInstaller.installedCount()
                await MainActor.run {
                    self.status = ok ? .done("\(count) commands installed")
                                     : .failed("install-specs.sh exited \(proc.terminationStatus)")
                }
            } catch {
                await MainActor.run { self.status = .failed("\(error)") }
            }
        }
    }
}
