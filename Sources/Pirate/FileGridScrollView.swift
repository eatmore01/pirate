import AppKit

// Drag-destination handling lives here, one level above NSCollectionView,
// after NSCollectionView-level and NSImageView-level implementations both
// showed an unreliable drop right at an icon's dead center.
final class FileGridScrollView: NSScrollView {
    weak var gridView: FileGridView?

    var dropIndexPathResolver: ((NSPoint) -> IndexPath?)?
    var dropValidator: ((IndexPath?, NSDraggingInfo) -> Bool)?
    var dropHandler: ((IndexPath?, NSDraggingInfo) -> Void)?

    private var highlightedDropIndexPath: IndexPath?

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        updateDropTarget(sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        updateDropTarget(sender)
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        clearDropHighlight()
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        clearDropHighlight()
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        defer { clearDropHighlight() }
        let indexPath = dropIndexPathResolver?(sender.draggingLocation)
        guard dropValidator?(indexPath, sender) == true else { return false }
        dropHandler?(indexPath, sender)
        return true
    }

    private func updateDropTarget(_ sender: NSDraggingInfo) -> NSDragOperation {
        let indexPath = dropIndexPathResolver?(sender.draggingLocation)
        guard dropValidator?(indexPath, sender) == true else {
            clearDropHighlight()
            return []
        }
        if let indexPath {
            setDropHighlight(indexPath)
        } else {
            clearDropHighlight()
        }
        return .move
    }

    private func setDropHighlight(_ indexPath: IndexPath) {
        guard highlightedDropIndexPath != indexPath else { return }
        clearDropHighlight()
        highlightedDropIndexPath = indexPath
        gridView?.item(at: indexPath)?.highlightState = .asDropTarget
    }

    private func clearDropHighlight() {
        if let old = highlightedDropIndexPath {
            gridView?.item(at: old)?.highlightState = .none
        }
        highlightedDropIndexPath = nil
    }
}
