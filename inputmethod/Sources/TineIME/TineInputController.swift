import Cocoa
import InputMethodKit

/// Passthrough input method: never consumes keystrokes (typing is unaffected),
/// but on each event it reads the client's caret rect — which terminals expose
/// to input methods via NSTextInputClient even when their Accessibility is
/// broken (Ghostty) — and forwards it to the tine app over the socket.
@objc(TineInputController)
final class TineInputController: IMKInputController {
    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        forwardCaret(sender)
        return false // passthrough — let the app insert the character normally
    }

    override func activateServer(_ sender: Any!) {
        super.activateServer(sender)
        forwardCaret(sender)
    }

    private func forwardCaret(_ sender: Any!) {
        guard let client = sender as? IMKTextInput else { return }
        var rect = NSRect.zero
        _ = client.attributes(forCharacterIndex: 0, lineHeightRectangle: &rect)
        guard rect.origin.x.isFinite, rect.origin.y.isFinite else { return }
        CaretSocket.send(x: rect.origin.x, y: rect.origin.y, height: rect.height)
    }
}
