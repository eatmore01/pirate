import AppKit

// NSImageView appears to independently intercept NSDraggingDestination
// callbacks over its own bounds (they don't bubble like ordinary mouse
// events), which breaks drop detection exactly over the icon. Making it
// transparent to hit-testing routes everything to the container/collection
// view instead, where drag handling actually lives.
final class NonHitTestingImageView: NSImageView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
