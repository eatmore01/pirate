import AppKit
import UniformTypeIdentifiers

@MainActor
protocol SidebarSelectionHandling: AnyObject {
    func sidebarDidSelect(url: URL)
}

private let favoritesGroupTitle = "Favorites"
private let favoriteColumnID = NSUserInterfaceItemIdentifier("favorite")
private let baseSidebarIconSize: CGFloat = 20
private let baseSidebarRowHeight: CGFloat = 24

@MainActor
final class SidebarController: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate, SidebarDeleteHandling {

    let scrollView = NSScrollView()
    let outlineView = SidebarOutlineView()
    let addButton = NSButton()

    private let store = FavoritesStore()
    weak var selectionHandler: SidebarSelectionHandling?
    var currentDirectoryProvider: (() -> URL)?

    override init() {
        super.init()
        setUp()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(configDidChange),
            name: ConfigStore.didChangeNotification,
            object: nil
        )
    }

    @objc private func configDidChange() {
        applyRowHeight()
        reloadData()
    }

    private func applyRowHeight() {
        outlineView.rowHeight = baseSidebarRowHeight * CGFloat(AppSettings.shared.iconScale)
    }

    private func setUp() {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("sidebarColumn"))
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        outlineView.headerView = nil
        outlineView.style = .sourceList
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.deleteHandler = self
        outlineView.target = self
        outlineView.action = #selector(didClickRow)

        scrollView.documentView = outlineView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = Theme.surface
        outlineView.backgroundColor = .clear

        addButton.bezelStyle = .texturedRounded
        addButton.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "Add current folder to Favorites")
        addButton.target = self
        addButton.action = #selector(didTapAdd)

        applyRowHeight()
        reloadData()
    }

    private func reloadData() {
        outlineView.reloadData()
        outlineView.expandItem(favoritesGroupTitle)
    }

    @objc private func didTapAdd() {
        guard let url = currentDirectoryProvider?() else { return }
        store.add(url: url)
        reloadData()
    }

    @objc private func didClickRow() {
        guard outlineView.selectedRow >= 0,
              let favorite = outlineView.item(atRow: outlineView.selectedRow) as? FavoriteItem,
              let url = favorite.resolvedURL() else {
            return
        }
        selectionHandler?.sidebarDidSelect(url: url)
    }

    // MARK: - SidebarDeleteHandling

    func sidebarDidRequestDelete() {
        guard outlineView.selectedRow >= 0,
              outlineView.item(atRow: outlineView.selectedRow) is FavoriteItem else {
            return
        }
        guard let index = store.items.firstIndex(where: { item in
            guard let favorite = outlineView.item(atRow: outlineView.selectedRow) as? FavoriteItem else { return false }
            return item.bookmarkData == favorite.bookmarkData
        }) else { return }
        store.remove(at: index)
        reloadData()
    }

    // MARK: - NSOutlineViewDataSource

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil { return 1 }
        if (item as? String) == favoritesGroupTitle { return store.items.count }
        return 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil { return favoritesGroupTitle }
        return store.items[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        (item as? String) == favoritesGroupTitle
    }

    // MARK: - NSOutlineViewDelegate

    func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
        (item as? String) == favoritesGroupTitle
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        if let groupTitle = item as? String {
            let id = NSUserInterfaceItemIdentifier("sidebarGroup")
            let cell: NSTableCellView
            if let reused = outlineView.makeView(withIdentifier: id, owner: self) as? NSTableCellView {
                cell = reused
            } else {
                cell = NSTableCellView()
                cell.identifier = id
                let textField = NSTextField(labelWithString: "")
                textField.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
                textField.textColor = Theme.textSecondary
                textField.translatesAutoresizingMaskIntoConstraints = false
                cell.addSubview(textField)
                cell.textField = textField
                NSLayoutConstraint.activate([
                    textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                    textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
                ])
            }
            cell.textField?.stringValue = groupTitle as String
            return cell
        }

        guard let favorite = item as? FavoriteItem else { return nil }
        let cell: NSTableCellView
        if let reused = outlineView.makeView(withIdentifier: favoriteColumnID, owner: self) as? NSTableCellView {
            cell = reused
        } else {
            cell = NSTableCellView()
            cell.identifier = favoriteColumnID

            let imageView = NSImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(imageView)
            cell.imageView = imageView

            let textField = NSTextField(labelWithString: "")
            textField.lineBreakMode = .byTruncatingTail
            textField.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(textField)
            cell.textField = textField

            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
                imageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                imageView.widthAnchor.constraint(equalToConstant: baseSidebarIconSize),
                imageView.heightAnchor.constraint(equalToConstant: baseSidebarIconSize),
                textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 6),
                textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
        }

        cell.textField?.stringValue = favorite.name
        cell.textField?.textColor = Theme.textPrimary
        cell.imageView?.image = NSWorkspace.shared.icon(for: .folder)
        DirectoryEntryCellFactory.applyIconSize(baseSidebarIconSize * CGFloat(AppSettings.shared.iconScale), to: cell.imageView)
        return cell
    }
}
