import Foundation

/// Ranks suggestions by how recently the user used a command's subcommands/flags.
/// The index is `[rawCommand: [param: lastUsedMillis]]`, matching the engine's
/// sorting.ts (recencyBoost = value / 1e13). Bootstrapped from ~/.zsh_history and
/// extended with live picks persisted to ~/.local/share/tine/frecency.json.
final class Frecency {
    static let storePath = "\(NSHomeDirectory())/.local/share/tine/frecency.json"
    private static let historyPath = "\(NSHomeDirectory())/.zsh_history"
    private static let maxHistoryLines = 8000

    /// history ∪ live — fed to the engine as globalThis.__tineFrecency.
    private(set) var index: [String: [String: Double]] = [:]
    /// Only the live picks (persisted); merged over history on load.
    private var live: [String: [String: Double]] = [:]

    func load() {
        index = Self.parseHistory()
        if let data = FileManager.default.contents(atPath: Self.storePath),
           let obj = try? JSONDecoder().decode([String: [String: Double]].self, from: data) {
            live = obj
            for (cmd, params) in live {
                for (p, t) in params { index[cmd, default: [:]][p] = max(index[cmd]?[p] ?? 0, t) }
            }
        }
    }

    /// Record a pick (cmd = raw first token, param = accepted suggestion name).
    func record(cmd: String, param: String) {
        guard !cmd.isEmpty, !param.isEmpty, !param.contains("↪"), !param.contains(" ") else { return }
        let now = Date().timeIntervalSince1970 * 1000
        live[cmd, default: [:]][param] = now
        index[cmd, default: [:]][param] = now
        persistLive()
    }

    private func persistLive() {
        let dir = (Self.storePath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(live) {
            try? data.write(to: URL(fileURLWithPath: Self.storePath))
        }
    }

    /// Keep only subcommand/flag-like tokens; skip paths, URLs, quoted args.
    private static func isRankable(_ t: String) -> Bool {
        if t.isEmpty || t.count > 40 { return false }
        if t.hasPrefix("-") { return t.count > 1 }               // flags
        guard let first = t.first, first.isLetter || first.isNumber else { return false }
        return t.allSatisfy { $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" || $0 == "_" }
    }

    private static func parseHistory() -> [String: [String: Double]] {
        let raw = (try? String(contentsOfFile: historyPath, encoding: .utf8))
            ?? String(data: FileManager.default.contents(atPath: historyPath) ?? Data(), encoding: .ascii)
        guard let raw else { return [:] }

        var lines = raw.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        if lines.count > maxHistoryLines { lines = Array(lines.suffix(maxHistoryLines)) }

        var idx: [String: [String: Double]] = [:]
        let nowMs = Date().timeIntervalSince1970 * 1000
        for (i, line) in lines.enumerated() {
            var cmd = line
            var ts = nowMs - Double(lines.count - i)            // fallback: preserve order
            // zsh extended history: ": <epoch>:<dur>;<command>"
            if line.hasPrefix(":"), let semi = line.firstIndex(of: ";") {
                let meta = line[line.index(after: line.startIndex)..<semi]
                let parts = meta.split(separator: ":")
                if let epoch = parts.first.flatMap({ Double($0.trimmingCharacters(in: .whitespaces)) }) {
                    ts = epoch * 1000
                }
                cmd = String(line[line.index(after: semi)...])
            }
            let tokens = cmd.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
            guard let root = tokens.first, !root.isEmpty else { continue }
            // cd targets are paths (skipped by isRankable): record the destination's
            // basename + "/" so it matches the folder suggestion names cd produces.
            if root == "cd", let target = tokens.dropFirst().first {
                let base = (target as NSString).lastPathComponent
                if !base.isEmpty, base != "/", base != "-" {
                    let key = base + "/"
                    idx["cd", default: [:]][key] = max(idx["cd"]?[key] ?? 0, ts)
                }
            }
            for t in tokens.dropFirst() where isRankable(t) {
                idx[root, default: [:]][t] = max(idx[root]?[t] ?? 0, ts)
            }
        }
        return idx
    }
}
