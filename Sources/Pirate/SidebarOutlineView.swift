import AppKit

private let kVK_Delete: UInt16 = 0x33

@MainActor
protocol SidebarDeleteHandling: AnyObject {
    func sidebarDidRequestDelete()
}

final class SidebarOutlineView: NSOutlineView {
    weak var deleteHandler: SidebarDeleteHandling?

    private var hoverTrackingArea: NSTrackingArea?
    private var hoveredRow = -1

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        hoverTrackingArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        setHover(row(at: convert(event.locationInWindow, from: nil)))
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        clearHover()
    }

    override func scrollWheel(with event: NSEvent) {
        super.scrollWheel(with: event)
        guard let window else { return }
        setHover(row(at: convert(window.mouseLocationOutsideOfEventStream, from: nil)))
    }

    func clearHover() {
        setHover(-1)
    }

    private func setHover(_ row: Int) {
        guard hoveredRow != row else { return }
        if hoveredRow >= 0, hoveredRow < numberOfRows,
           let old = rowView(atRow: hoveredRow, makeIfNecessary: false) as? HoverTableRowView {
            old.isHovered = false
        }
        hoveredRow = row
        if row >= 0, row < numberOfRows,
           let new = rowView(atRow: row, makeIfNecessary: false) as? HoverTableRowView {
            new.isHovered = true
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == kVK_Delete {
            deleteHandler?.sidebarDidRequestDelete()
            return
        }
        super.keyDown(with: event)
    }
}
