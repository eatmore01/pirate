import AppKit

private let kVK_UpArrow: UInt16 = 0x7E
private let kVK_DownArrow: UInt16 = 0x7D
private let kVK_Delete: UInt16 = 0x33
private let kVK_ANSI_Z: UInt16 = 0x06
private let kVK_ANSI_C: UInt16 = 0x08
private let kVK_ANSI_V: UInt16 = 0x09
private let kVK_ANSI_R: UInt16 = 0x0F
private let kVK_Return: UInt16 = 0x24
private let kVK_ANSI_A: UInt16 = 0x00
private let kVK_ANSI_Equal: UInt16 = 0x18
private let kVK_ANSI_Minus: UInt16 = 0x1B
private let kVK_ANSI_D: UInt16 = 0x02

final class FileGridView: NSCollectionView {
    weak var navigationHandler: FileListNavigationHandling?
    weak var actionHandler: FileListActionHandling?
    var doubleClickHandler: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    private var hoverTrackingArea: NSTrackingArea?
    private var hoveredIndexPath: IndexPath?

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
        setHover(indexPathForItem(at: convert(event.locationInWindow, from: nil)))
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        clearHover()
    }

    override func scrollWheel(with event: NSEvent) {
        super.scrollWheel(with: event)
        guard let window else { return }
        setHover(indexPathForItem(at: convert(window.mouseLocationOutsideOfEventStream, from: nil)))
    }

    func clearHover() {
        setHover(nil)
    }

    private func setHover(_ indexPath: IndexPath?) {
        guard hoveredIndexPath != indexPath else { return }
        if let hoveredIndexPath, let old = item(at: hoveredIndexPath) as? GridCollectionViewItem {
            old.isHovered = false
        }
        hoveredIndexPath = indexPath
        if let indexPath, let new = item(at: indexPath) as? GridCollectionViewItem {
            new.isHovered = true
        }
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        if event.clickCount == 2 {
            doubleClickHandler?()
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            switch event.keyCode {
            case kVK_UpArrow:
                navigationHandler?.navigateToParent()
                return
            case kVK_DownArrow:
                navigationHandler?.enterSelectedItem()
                return
            case kVK_ANSI_A:
                actionHandler?.createNewItem()
                return
            case kVK_ANSI_Z:
                if event.modifierFlags.contains(.shift) {
                    actionHandler?.redo()
                } else {
                    actionHandler?.undo()
                }
                return
            case kVK_ANSI_C:
                actionHandler?.copySelectedItemToPasteboard()
                return
            case kVK_ANSI_V:
                actionHandler?.pasteFromPasteboard()
                return
            case kVK_ANSI_R:
                actionHandler?.renameSelectedItem()
                return
            case kVK_ANSI_Equal:
                actionHandler?.zoomIn()
                return
            case kVK_ANSI_Minus:
                actionHandler?.zoomOut()
                return
            case kVK_ANSI_D:
                actionHandler?.deleteSelectedItem()
                return
            default:
                break
            }
        } else if event.keyCode == kVK_Delete {
            actionHandler?.deleteSelectedItem()
            return
        } else if event.keyCode == kVK_Return {
            actionHandler?.renameSelectedItem()
            return
        }
        super.keyDown(with: event)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let point = convert(event.locationInWindow, from: nil)
        if let indexPath = indexPathForItem(at: point), !selectionIndexPaths.contains(indexPath) {
            selectionIndexPaths = [indexPath]
        }
        return super.menu(for: event)
    }
}
