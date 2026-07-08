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
    /// `origin` (Cocoa coords, just below the caret) so it grows downward — but
    /// keep it fully on-screen: shift left off the right edge, and flip above the
    /// caret line (using its `lineHeight`) if it would run off the bottom.
    func present(at origin: CGPoint, lineHeight: CGFloat, gap: CGFloat = 4) {
        let rows = min(max(state.suggestions.count, 1), max(1, state.config.maxVisibleRows))
        let height = rowHeight * CGFloat(rows) + 8   // + list's vertical padding
        setContentSize(NSSize(width: width, height: height))

        var o = origin
        if let vf = (NSScreen.screens.first { $0.frame.contains(origin) } ?? NSScreen.main)?.visibleFrame {
            o.x = min(max(o.x, vf.minX), max(vf.minX, vf.maxX - width))
            // The panel spans [o.y - height, o.y]. If its bottom falls off-screen,
            // flip it above the caret: its bottom sits just above the caret's top.
            // origin.y is gap below the caret, so caretTop = origin.y + gap + lineHeight.
            if o.y - height < vf.minY {
                o.y = origin.y + gap + lineHeight + gap + height
            }
            o.y = min(o.y, vf.maxY)
        }
        setFrameTopLeftPoint(o)
        orderFrontRegardless()
    }

    /// Re-apply size at the current position (after a detail-pane toggle).
    func relayout() {
        guard isVisible else { return }
        present(at: CGPoint(x: frame.minX, y: frame.maxY), lineHeight: rowHeight)
    }

    func hidePanel() { orderOut(nil) }
}
