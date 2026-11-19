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

@MainActor
protocol FileListNavigationHandling: AnyObject {
    func navigateToParent()
    func enterSelectedItem()
}

@MainActor
protocol FileListActionHandling: AnyObject {
    func deleteSelectedItem()
    func renameSelectedItem()
    func createNewItem()
    func copySelectedItemToPasteboard()
    func pasteFromPasteboard()
    func undo()
    func redo()
    func zoomIn()
    func zoomOut()
}

final class FileListTableView: NSTableView {
    weak var navigationHandler: FileListNavigationHandling?
    weak var actionHandler: FileListActionHandling?

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
        let row = row(at: point)
        if row >= 0, !selectedRowIndexes.contains(row) {
            selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        }
        return super.menu(for: event)
    }
}
