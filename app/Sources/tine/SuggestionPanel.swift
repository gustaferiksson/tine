import AppKit
import SwiftUI

/// Small floating, non-activating suggestion window. Never steals focus from the
/// terminal, floats above other windows, follows across spaces.
final class SuggestionPanel: NSPanel {
    private let state: AppState
    private var rowHeight: CGFloat { CGFloat(state.config.fontSize) + 12 }
    private var width: CGFloat {
        SuggestionListView.listWidth + (state.config.showDetail ? SuggestionListView.detailWidth : 0)
    }

    init(state: AppState) {
        self.state = state
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: SuggestionListView.listWidth, height: 24),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: true
        )
        isFloatingPanel = true
        level = .popUpMenu
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let host = NSHostingView(rootView: SuggestionListView().environmentObject(state))
        host.autoresizingMask = [.width, .height]
        contentView = host
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Resize to fit the current suggestions, then place the panel's top-left at
    /// `origin` (Cocoa coords) so it grows downward from the caret.
    func present(at origin: CGPoint) {
        let rows = min(max(state.suggestions.count, 1), max(1, state.config.maxVisibleRows))
        let height = rowHeight * CGFloat(rows) + 8   // + list's vertical padding
        setContentSize(NSSize(width: width, height: height))
        setFrameTopLeftPoint(origin)
        orderFrontRegardless()
    }

    /// Re-apply size at the current position (after a detail-pane toggle).
    func relayout() {
        guard isVisible else { return }
        present(at: CGPoint(x: frame.minX, y: frame.maxY))
    }

    func hidePanel() { orderOut(nil) }
}
