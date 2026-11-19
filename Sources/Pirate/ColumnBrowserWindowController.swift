import AppKit

@MainActor
final class ColumnBrowserWindowController: NSWindowController, ColumnPaneSelectionHandling, NSWindowDelegate {

    private let paneWidth: CGFloat = 220
    private var panes: [ColumnPane] = []

    private let outerScrollView = NSScrollView()
    private let containerView = NSView()

    init(startingAt url: URL) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 480),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)
        window.center()
        window.delegate = self
        setUpScrollView()
        pushColumn(for: url)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("not supported")
    }

    private func setUpScrollView() {
        guard let window else { return }

        outerScrollView.frame = window.contentView?.bounds ?? .zero
        outerScrollView.autoresizingMask = [.width, .height]
        outerScrollView.hasHorizontalScroller = true
        outerScrollView.hasVerticalScroller = false
        outerScrollView.documentView = containerView

        window.contentView = outerScrollView
    }

    private func pushColumn(for url: URL) {
        let entries: [DirectoryEntry]
        do {
            entries = DirectoryLister.sorted(try DirectoryLister.listDirectory(at: url))
        } catch {
            entries = []
            NSSound.beep()
        }

        let pane = ColumnPane(index: panes.count, url: url, entries: entries)
        pane.selectionHandler = self
        panes.append(pane)
        containerView.addSubview(pane.scrollView)

        layoutPanes()
        revealLastPane()
        window?.title = url.path
    }

    private func layoutPanes() {
        let height = outerScrollView.contentView.bounds.height
        for (i, pane) in panes.enumerated() {
            pane.scrollView.frame = NSRect(x: CGFloat(i) * paneWidth, y: 0, width: paneWidth, height: height)
        }
        containerView.frame = NSRect(x: 0, y: 0, width: CGFloat(panes.count) * paneWidth, height: height)
    }

    private func revealLastPane() {
        guard let last = panes.last else { return }
        outerScrollView.contentView.scrollToVisible(last.scrollView.frame)
    }

    // MARK: - ColumnPaneSelectionHandling

    func columnPane(_ pane: ColumnPane, didSelectRow row: Int) {
        while panes.count > pane.index + 1 {
            let removed = panes.removeLast()
            removed.scrollView.removeFromSuperview()
        }
        layoutPanes()

        guard row >= 0, row < pane.entries.count else { return }
        let entry = pane.entries[row]
        guard entry.isDirectory else { return }
        pushColumn(for: entry.url)
    }

    // MARK: - NSWindowDelegate

    func windowDidResize(_ notification: Notification) {
        layoutPanes()
    }
}
