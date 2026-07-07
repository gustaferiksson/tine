import Foundation

let TINE_US = "\u{1f}"

/// One request from the shell feed (shell/tine.zsh).
/// Wire format (one line): type US cursor US cwd US buffer
struct Request {
    let type: String   // update | up | down | accept | dismiss
    let cursor: Int
    let cwd: String
    let buffer: String
}

struct FeedMessage {
    let cursor: Int
    let cwd: String
    let buffer: String
}

/// Unix-domain-socket request/response server. No pseudo-terminal (replaces
/// figterm). The handler runs on the main thread and returns the reply line.
final class SocketServer {
    private let path: String
    private let handler: (Request) -> String
    private var fd: Int32 = -1

    init(path: String, handler: @escaping (Request) -> String) {
        self.path = path
        self.handler = handler
    }

    func start() {
        unlink(path)
        fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { perror("tine socket"); return }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let sunPathSize = MemoryLayout.size(ofValue: addr.sun_path)
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            path.withCString { cs in
                let dst = UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: CChar.self)
                strncpy(dst, cs, sunPathSize - 1)
            }
        }
        let len = socklen_t(MemoryLayout<sockaddr_un>.size)
        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, len) }
        }
        guard bound == 0 else { perror("tine bind"); return }
        guard listen(fd, 16) == 0 else { perror("tine listen"); return }

        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            self?.acceptLoop()
        }
    }

    private func acceptLoop() {
        while true {
            let conn = accept(fd, nil, nil)
            if conn < 0 { break }
            handle(conn)
            close(conn)
        }
    }

    private func handle(_ conn: Int32) {
        // Read one newline-terminated request line.
        var data = Data()
        var chunk = [UInt8](repeating: 0, count: 4096)
        readLoop: while true {
            let n = read(conn, &chunk, chunk.count)
            if n <= 0 { break }
            for i in 0..<n {
                if chunk[i] == 0x0a { break readLoop }
                data.append(chunk[i])
            }
        }
        guard let req = parse(data) else { return }

        var reply = ""
        DispatchQueue.main.sync { reply = handler(req) }

        var out = Array((reply + "\n").utf8)
        _ = write(conn, &out, out.count)
    }

    private func parse(_ data: Data) -> Request? {
        guard let s = String(data: data, encoding: .utf8) else { return nil }
        let parts = s.components(separatedBy: TINE_US)
        guard parts.count >= 4 else { return nil }
        return Request(
            type: parts[0],
            cursor: Int(parts[1]) ?? 0,
            cwd: parts[2],
            buffer: parts[3...].joined(separator: TINE_US)
        )
    }
}
