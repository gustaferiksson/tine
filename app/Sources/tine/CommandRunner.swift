import Foundation

/// Runs the shell commands that Fig generators request (git branch, ls, ).
/// Synchronous with a timeout — fits the engine's synchronous suggestion pass.
/// Input/output are JSON to keep the JS<->Swift boundary simple.
enum CommandRunner {
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
        let proc = Process()
        // Resolve the executable via PATH.
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        proc.arguments = [executable] + args
        if let cwd = input["workingDirectory"] as? String, !cwd.isEmpty {
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

        let timeoutMs = input["timeout"] as? Double
        let timeout = timeoutMs.map { $0 / 1000.0 } ?? 5.0
        let killer = DispatchWorkItem { if proc.isRunning { proc.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: killer)

        let out = outPipe.fileHandleForReading.readDataToEndOfFile()
        let err = errPipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        killer.cancel()

        return encode(
            stdout: String(data: out, encoding: .utf8) ?? "",
            stderr: String(data: err, encoding: .utf8) ?? "",
            exitCode: proc.terminationStatus
        )
    }
}
