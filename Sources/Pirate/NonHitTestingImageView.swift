import AppKit

final class NonHitTestingImageView: NSImageView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        unregisterDraggedTypes()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        unregisterDraggedTypes()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
