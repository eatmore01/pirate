import AppKit

final class HoverTableRowView: NSTableRowView {
    var isHovered = false {
        didSet {
            guard oldValue != isHovered else { return }
            needsDisplay = true
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        isHovered = false
    }

    override func drawBackground(in dirtyRect: NSRect) {
        super.drawBackground(in: dirtyRect)
        guard isHovered, !isSelected, !isGroupRowStyle else { return }
        NSColor.selectedContentBackgroundColor.withAlphaComponent(0.1).setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 1), xRadius: 6, yRadius: 6).fill()
    }
}
