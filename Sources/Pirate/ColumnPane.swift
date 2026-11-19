import AppKit

private let paneNameColumnID = NSUserInterfaceItemIdentifier("name")

@MainActor
final class ColumnPane: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    let index: Int
    let url: URL
    private(set) var entries: [DirectoryEntry]
    let tableView = NSTableView()
    let scrollView = NSScrollView()

    weak var selectionHandler: ColumnPaneSelectionHandling?

    init(index: Int, url: URL, entries: [DirectoryEntry]) {
        self.index = index
        self.url = url
        self.entries = entries
        super.init()
        setUpViews()
    }

    private func setUpViews() {
        let column = NSTableColumn(identifier: paneNameColumnID)
        column.title = "Name"
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsMultipleSelection = false
        tableView.rowSizeStyle = .default

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.documentView = tableView
        scrollView.borderType = .lineBorder
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        entries.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < entries.count else { return nil }
        let cell = DirectoryEntryCellFactory.makeOrReuseNameCell(in: tableView, identifier: paneNameColumnID, owner: self)
        DirectoryEntryCellFactory.configure(cell, for: entries[row])
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        selectionHandler?.columnPane(self, didSelectRow: tableView.selectedRow)
    }
}

@MainActor
protocol ColumnPaneSelectionHandling: AnyObject {
    func columnPane(_ pane: ColumnPane, didSelectRow row: Int)
}
