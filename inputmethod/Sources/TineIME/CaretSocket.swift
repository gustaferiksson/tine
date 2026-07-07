import Foundation

/// Sends the caret rect to the tine app over its unix socket. Uses a fixed,
/// HOME-based path (the IME process doesn't inherit the shell's TINE_SOCK env).
enum CaretSocket {
    static let path = "\(NSHomeDirectory())/.local/share/tine/tine.sock"

    static func send(x: CGFloat, y: CGFloat, height: CGFloat) {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return }
        defer { close(fd) }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let sunPathSize = MemoryLayout.size(ofValue: addr.sun_path)
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            path.withCString { cs in
                strncpy(UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: CChar.self), cs, sunPathSize - 1)
            }
        }
        let len = socklen_t(MemoryLayout<sockaddr_un>.size)
        let connected = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, len) }
        }
        guard connected == 0 else { return }

        // caret US x US y US height  (matches the app's Request parser)
        let msg = "caret\u{1f}\(Int(x))\u{1f}\(Int(y))\u{1f}\(Int(height))\n"
        _ = msg.withCString { write(fd, $0, strlen($0)) }
    }
}
