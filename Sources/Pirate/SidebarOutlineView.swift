import AppKit

private let kVK_Delete: UInt16 = 0x33

@MainActor
protocol SidebarDeleteHandling: AnyObject {
    func sidebarDidRequestDelete()
}

final class SidebarOutlineView: NSOutlineView {
    weak var deleteHandler: SidebarDeleteHandling?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == kVK_Delete {
            deleteHandler?.sidebarDidRequestDelete()
            return
        }
        super.keyDown(with: event)
    }
}
