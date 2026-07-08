import Foundation

/// Runs the shell commands that Fig generators request (git branch, ls, …).
/// Synchronous with a timeout — fits the engine's synchronous suggestion pass.
/// Input/output are JSON to keep the JS<->Swift boundary simple.
enum CommandRunner {
    // The engine's generator cache uses stale-while-revalidate: it returns the
    // cached result but still re-runs the generator to revalidate on every
    // keystroke. Because this bridge is synchronous, that revalidation spawns a
    // blocking subprocess per character — the per-key lag when typing a
    // `git checkout <branch>` argument. Cache the raw output briefly, keyed by the
    // exact command, so repeated identical calls skip the subprocess entirely.
    // Called only on the main thread (from the engine during a suggest pass).
    private static var cache: [String: (output: String, at: Date)] = [:]
    private static let ttl: TimeInterval = 3

    static func run(_ inputJSON: String) -> String {
        func encode(stdout: String, stderr: String, exitCode: Int32) -> String {
            let obj: [String: Any] = ["stdout": stdout, "stderr": stderr, "exitCode": Int(exitCode)]
            let data = (try? JSONSerialization.data(withJSONObject: obj)) ?? Data()
            return String(data: data, encoding: .utf8) ?? #"{"stdout":"","stderr":"","exitCode":1}"#
        }

        guard let data = inputJSON.data(using: .utf8),
              let input = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let executable = input["executable"] as? String, !executable.isEmpty
        else { return encode(stdout: "", stderr: "tine: bad command input", exitCode: 1) }

        let args = input["args"] as? [String] ?? []
        let cwd = input["workingDirectory"] as? String ?? ""

        let key = "\(cwd)\u{1f}\(executable)\u{1f}\(args.joined(separator: "\u{1f}"))"
        if let hit = cache[key], Date().timeIntervalSince(hit.at) < ttl {
            return hit.output
        }

        let proc = Process()
        // Resolve the executable via PATH.
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        proc.arguments = [executable] + args
        if !cwd.isEmpty {
            proc.currentDirectoryURL = URL(fileURLWithPath: cwd)
        }
        var environment = ProcessInfo.processInfo.environment
        if let env = input["environment"] as? [String: String] {
            for (k, v) in env { environment[k] = v }
        }
        proc.environment = environment

        let outPipe = Pipe(), errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe

        do { try proc.run() } catch {
            return encode(stdout: "", stderr: "\(error)", exitCode: 127)
        }

        // This runs synchronously on the main thread inside a suggest pass, so the
        // shell keystroke blocks until it returns. Cap the wait at 2s (was 5s) so a
        // slow/hung generator can't freeze typing — stale-while-revalidate covers
        // the empty result, and real generators (git branch, ls) finish well under.
        let timeoutMs = input["timeout"] as? Double
        let timeout = min(timeoutMs.map { $0 / 1000.0 } ?? 2.0, 2.0)
        let killer = DispatchWorkItem { if proc.isRunning { proc.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: killer)

        let out = outPipe.fileHandleForReading.readDataToEndOfFile()
        let err = errPipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        killer.cancel()

        let result = encode(
            stdout: String(data: out, encoding: .utf8) ?? "",
            stderr: String(data: err, encoding: .utf8) ?? "",
            exitCode: proc.terminationStatus
        )
        cache[key] = (result, Date())
        if cache.count > 128 {
            cache = cache.filter { Date().timeIntervalSince($0.value.at) < ttl }
        }
        return result
    }
}
