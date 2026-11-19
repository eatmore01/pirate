import AppKit
import UniformTypeIdentifiers

private enum ColumnID {
    static let name = NSUserInterfaceItemIdentifier("name")
    static let size = NSUserInterfaceItemIdentifier("size")
    static let modified = NSUserInterfaceItemIdentifier("modified")
    static let kind = NSUserInterfaceItemIdentifier("kind")
}

@MainActor
final class FileListWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSCollectionViewDataSource, NSCollectionViewDelegate, FileListNavigationHandling, FileListActionHandling, SidebarSelectionHandling, NSSplitViewDelegate, NSWindowDelegate {

    private let tableView = FileListTableView()
    private let gridView = FileGridView(frame: .zero)
    private let sidebar = SidebarController()
    private let fileUndoManager = UndoManager()
    private var currentURL: URL
    private var rawEntries: [DirectoryEntry] = []
    private var displayedEntries: [DirectoryEntry] = []
    private var sortKey: DirectoryLister.SortKey = .name
    private var sortAscending = true
    private var directoryWatcher: DispatchSourceFileSystemObject?
    private var pendingRescan: DispatchWorkItem?
    private var listScrollView: NSScrollView!
    private var gridScrollView: NSScrollView!
    private var gridLayout: NSCollectionViewFlowLayout!
    private let gridItemID = NSUserInterfaceItemIdentifier("gridItem")
    private let pathLabel = ClickableLabel(labelWithString: "")
    private static let baseRowHeight: CGFloat = 24

    private let sizeFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f
    }()

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    init(startingAt url: URL) {
        self.currentURL = url
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1140, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)
        window.center()
        window.delegate = self
        window.titleVisibility = .hidden
        setUpTableView()
        updateVisibleView()
        reload()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(configDidChange),
            name: ConfigStore.didChangeNotification,
            object: nil
        )
    }

    @objc private func configDidChange() {
        applyIconScale()
        applySortAndReload()
        updateVisibleView()
    }

    private func applyIconScale() {
        let scale = CGFloat(AppSettings.shared.iconScale)
        tableView.rowHeight = Self.baseRowHeight * scale
        gridLayout.itemSize = NSSize(
            width: GridCollectionViewItem.baseItemSize.width * scale,
            height: GridCollectionViewItem.baseItemSize.height * scale
        )
        gridLayout.invalidateLayout()
    }

    func zoomIn() {
        AppSettings.shared.iconScale += 0.15
    }

    func zoomOut() {
        AppSettings.shared.iconScale -= 0.15
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("not supported")
    }

    private let upButton = NSButton()
    private let settingsButton = NSButton()

    private func setUpTableView() {
        guard let window else { return }

        let containerView = NSView(frame: window.contentView?.bounds ?? .zero)
        containerView.autoresizingMask = [.width, .height]
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = Theme.ground.cgColor

        let topBar = NSView()
        topBar.translatesAutoresizingMaskIntoConstraints = false
        topBar.wantsLayer = true
        topBar.layer?.backgroundColor = Theme.surface.cgColor

        upButton.translatesAutoresizingMaskIntoConstraints = false
        upButton.bezelStyle = .texturedRounded
        upButton.image = NSImage(systemSymbolName: "chevron.left", accessibilityDescription: "Back")
        upButton.target = self
        upButton.action = #selector(didTapUpButton)
        topBar.addSubview(upButton)

        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.bezelStyle = .texturedRounded
        settingsButton.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings")
        settingsButton.target = self
        settingsButton.action = #selector(didTapSettings)
        topBar.addSubview(settingsButton)

        pathLabel.translatesAutoresizingMaskIntoConstraints = false
        pathLabel.alignment = .center
        pathLabel.lineBreakMode = .byTruncatingMiddle
        pathLabel.font = NSFont.systemFont(ofSize: 12)
        pathLabel.textColor = Theme.textSecondary
        pathLabel.toolTip = "Click to copy full path"
        pathLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        pathLabel.onClick = { [weak self] in self?.didClickPathLabel() }
        topBar.addSubview(pathLabel)

        containerView.addSubview(topBar)

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = Theme.ground
        containerView.addSubview(scrollView)
        self.listScrollView = scrollView

        let gridScrollView = NSScrollView()
        gridScrollView.translatesAutoresizingMaskIntoConstraints = false
        gridScrollView.hasVerticalScroller = true
        gridScrollView.drawsBackground = true
        gridScrollView.backgroundColor = Theme.ground
        containerView.addSubview(gridScrollView)
        self.gridScrollView = gridScrollView

        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: containerView.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 36),

            upButton.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 8),
            upButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            upButton.widthAnchor.constraint(equalToConstant: 28),
            upButton.heightAnchor.constraint(equalToConstant: 28),

            settingsButton.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -8),
            settingsButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            settingsButton.widthAnchor.constraint(equalToConstant: 28),
            settingsButton.heightAnchor.constraint(equalToConstant: 28),

            pathLabel.leadingAnchor.constraint(equalTo: upButton.trailingAnchor, constant: 10),
            pathLabel.trailingAnchor.constraint(equalTo: settingsButton.leadingAnchor, constant: -10),
            pathLabel.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),

            scrollView.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

            gridScrollView.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            gridScrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            gridScrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            gridScrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        let gridLayout = NSCollectionViewFlowLayout()
        let scale = CGFloat(AppSettings.shared.iconScale)
        gridLayout.itemSize = NSSize(
            width: GridCollectionViewItem.baseItemSize.width * scale,
            height: GridCollectionViewItem.baseItemSize.height * scale
        )
        gridLayout.minimumInteritemSpacing = 8
        gridLayout.minimumLineSpacing = 12
        gridLayout.sectionInset = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        self.gridLayout = gridLayout

        gridView.collectionViewLayout = gridLayout
        gridView.navigationHandler = self
        gridView.actionHandler = self
        gridView.dataSource = self
        gridView.delegate = self
        gridView.isSelectable = true
        gridView.register(GridCollectionViewItem.self, forItemWithIdentifier: gridItemID)
        gridView.menu = makeContextMenu()
        gridView.doubleClickHandler = { [weak self] in self?.enterSelectedItem() }
        gridView.backgroundColors = [Theme.ground]

        gridScrollView.documentView = gridView

        tableView.navigationHandler = self
        tableView.actionHandler = self
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = Self.baseRowHeight * scale
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.backgroundColor = Theme.ground
        tableView.allowsMultipleSelection = false
        tableView.target = self
        tableView.doubleAction = #selector(didDoubleClickRow)
        tableView.menu = makeContextMenu()

        let nameColumn = NSTableColumn(identifier: ColumnID.name)
        nameColumn.title = "Name"
        nameColumn.width = 340
        nameColumn.sortDescriptorPrototype = NSSortDescriptor(key: "name", ascending: true)

        let sizeColumn = NSTableColumn(identifier: ColumnID.size)
        sizeColumn.title = "Size"
        sizeColumn.width = 100
        sizeColumn.sortDescriptorPrototype = NSSortDescriptor(key: "size", ascending: true)

        let modifiedColumn = NSTableColumn(identifier: ColumnID.modified)
        modifiedColumn.title = "Date Modified"
        modifiedColumn.width = 180
        modifiedColumn.sortDescriptorPrototype = NSSortDescriptor(key: "modified", ascending: true)

        let kindColumn = NSTableColumn(identifier: ColumnID.kind)
        kindColumn.title = "Kind"
        kindColumn.width = 120

        for column in [nameColumn, sizeColumn, modifiedColumn, kindColumn] {
            tableView.addTableColumn(column)
        }

        scrollView.documentView = tableView

        sidebar.selectionHandler = self
        sidebar.currentDirectoryProvider = { [weak self] in self?.currentURL ?? FileManager.default.homeDirectoryForCurrentUser }

        let sidebarContainer = NSView()
        sidebarContainer.translatesAutoresizingMaskIntoConstraints = false
        sidebar.scrollView.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addButton.translatesAutoresizingMaskIntoConstraints = false
        sidebarContainer.addSubview(sidebar.scrollView)
        sidebarContainer.addSubview(sidebar.addButton)

        NSLayoutConstraint.activate([
            sidebar.scrollView.topAnchor.constraint(equalTo: sidebarContainer.topAnchor),
            sidebar.scrollView.leadingAnchor.constraint(equalTo: sidebarContainer.leadingAnchor),
            sidebar.scrollView.trailingAnchor.constraint(equalTo: sidebarContainer.trailingAnchor),
            sidebar.scrollView.bottomAnchor.constraint(equalTo: sidebar.addButton.topAnchor, constant: -4),

            sidebar.addButton.leadingAnchor.constraint(equalTo: sidebarContainer.leadingAnchor, constant: 6),
            sidebar.addButton.bottomAnchor.constraint(equalTo: sidebarContainer.bottomAnchor, constant: -4),
            sidebar.addButton.heightAnchor.constraint(equalToConstant: 22)
        ])

        let splitView = NSSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.delegate = self
        splitView.addArrangedSubview(sidebarContainer)
        splitView.addArrangedSubview(containerView)
        splitView.setHoldingPriority(.defaultHigh, forSubviewAt: 0)

        window.contentView = splitView
        DispatchQueue.main.async {
            splitView.setPosition(180, ofDividerAt: 0)
        }
    }

    // MARK: - NSSplitViewDelegate

    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        160
    }

    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        280
    }

    private func reload() {
        do {
            rawEntries = try DirectoryLister.listDirectory(at: currentURL)
        } catch {
            rawEntries = []
            NSSound.beep()
        }
        applySortAndReload()
        window?.title = currentURL.path
        pathLabel.stringValue = currentURL.path
        upButton.isEnabled = currentURL.deletingLastPathComponent().path != currentURL.path
        startWatchingCurrentDirectory()
    }

    private func didClickPathLabel() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(currentURL.path, forType: .string)
    }

    // MARK: - Live updates

    private func startWatchingCurrentDirectory() {
        directoryWatcher?.cancel()
        directoryWatcher = nil

        let fd = open(currentURL.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            self?.scheduleRescan()
        }
        source.setCancelHandler {
            Darwin.close(fd)
        }
        source.resume()
        directoryWatcher = source
    }

    private func scheduleRescan() {
        pendingRescan?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.rescanAndDiff()
        }
        pendingRescan = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: workItem)
    }

    private func rescanAndDiff() {
        let newRawEntries: [DirectoryEntry]
        do {
            newRawEntries = try DirectoryLister.listDirectory(at: currentURL)
        } catch {
            // Directory likely gone (deleted/renamed out from under us).
            reload()
            return
        }

        rawEntries = newRawEntries
        var newDisplayed = DirectoryLister.sorted(rawEntries, by: sortKey, ascending: sortAscending)
        if !AppSettings.shared.showHiddenFiles {
            newDisplayed = newDisplayed.filter { !$0.isHidden }
        }

        let oldPaths = displayedEntries.map(\.url.path)
        let newPaths = newDisplayed.map(\.url.path)
        let oldPathSet = Set(oldPaths)
        let newPathSet = Set(newPaths)

        let removedIndexes = IndexSet(oldPaths.indices.filter { !newPathSet.contains(oldPaths[$0]) })
        let insertedIndexes = IndexSet(newPaths.indices.filter { !oldPathSet.contains(newPaths[$0]) })

        guard !removedIndexes.isEmpty || !insertedIndexes.isEmpty else {
            // No adds/removes - sizes, dates, etc. may still have changed in place.
            displayedEntries = newDisplayed
            tableView.reloadData()
            gridView.reloadData()
            return
        }

        displayedEntries = newDisplayed
        tableView.beginUpdates()
        if !removedIndexes.isEmpty {
            tableView.removeRows(at: removedIndexes, withAnimation: .slideUp)
        }
        if !insertedIndexes.isEmpty {
            tableView.insertRows(at: insertedIndexes, withAnimation: .slideDown)
        }
        tableView.endUpdates()
        // Grid mode gets a plain reload rather than an animated diff - acceptable for v1.
        gridView.reloadData()
    }

    func windowWillClose(_ notification: Notification) {
        directoryWatcher?.cancel()
        pendingRescan?.cancel()
    }

    @objc private func didTapUpButton() {
        navigateToParent()
    }

    @objc private func didTapSettings() {
        SettingsWindowController.shared.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func applySortAndReload() {
        var sorted = DirectoryLister.sorted(rawEntries, by: sortKey, ascending: sortAscending)
        if !AppSettings.shared.showHiddenFiles {
            sorted = sorted.filter { !$0.isHidden }
        }
        displayedEntries = sorted
        tableView.reloadData()
        gridView.reloadData()
        if !displayedEntries.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            gridView.selectionIndexPaths = [IndexPath(item: 0, section: 0)]
        }
    }

    private func updateVisibleView() {
        let isGrid = AppSettings.shared.viewMode == .grid
        gridScrollView.isHidden = !isGrid
        listScrollView.isHidden = isGrid
        _ = window?.makeFirstResponder(isGrid ? gridView : tableView)
    }

    // MARK: - NSCollectionViewDataSource

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        displayedEntries.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: gridItemID, for: indexPath)
        guard let gridItem = item as? GridCollectionViewItem, indexPath.item < displayedEntries.count else {
            return item
        }
        let iconSize = GridCollectionViewItem.baseIconSize * CGFloat(AppSettings.shared.iconScale)
        gridItem.configure(with: displayedEntries[indexPath.item], iconSize: iconSize)
        return gridItem
    }

    // MARK: - Navigation

    func navigateToParent() {
        let parent = currentURL.deletingLastPathComponent()
        guard parent.path != currentURL.path else { return }
        currentURL = parent
        reload()
    }

    func enterSelectedItem() {
        guard let entry = selectedEntry() else { return }
        if entry.isDirectory {
            currentURL = entry.url
            reload()
        } else {
            FileOpener.open(entry)
        }
    }

    @objc private func didDoubleClickRow() {
        enterSelectedItem()
    }

    // MARK: - Context menu / CRUD

    private func makeContextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "Open", action: #selector(openSelectedItem), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "New Item…", action: #selector(createNewItem), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Rename", action: #selector(renameSelectedItem), keyEquivalent: "")
        menu.addItem(withTitle: "Duplicate", action: #selector(duplicateSelectedItem), keyEquivalent: "")
        menu.addItem(withTitle: "Move to…", action: #selector(moveSelectedItem), keyEquivalent: "")
        menu.addItem(withTitle: "Copy to…", action: #selector(copySelectedItem), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Copy", action: #selector(copySelectedItemToPasteboard), keyEquivalent: "")
        menu.addItem(withTitle: "Paste", action: #selector(pasteFromPasteboard), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Move to Trash", action: #selector(deleteSelectedItem), keyEquivalent: "")
        for item in menu.items { item.target = self }
        return menu
    }

    @objc private func openSelectedItem() {
        enterSelectedItem()
    }

    private func selectedEntry() -> DirectoryEntry? {
        let index: Int
        if AppSettings.shared.viewMode == .grid {
            guard let indexPath = gridView.selectionIndexPaths.first else { return nil }
            index = indexPath.item
        } else {
            index = tableView.selectedRow
        }
        guard index >= 0, index < displayedEntries.count else { return nil }
        return displayedEntries[index]
    }

    private func showFileOperationError(_ error: Error) {
        guard let window else { return }
        let alert = NSAlert(error: error)
        alert.beginSheetModal(for: window)
    }

    @objc func deleteSelectedItem() {
        guard let entry = selectedEntry() else { return }
        do {
            try FileOperations.trash(entry.url, undoManager: fileUndoManager)
            reload()
        } catch {
            showFileOperationError(error)
        }
    }

    @objc func createNewItem() {
        guard let window else { return }

        let alert = NSAlert()
        alert.messageText = "New item"
        alert.informativeText = "A name with an extension creates a file (notes.txt); without one creates a folder. Use / to create nested folders, e.g. a/b/c.txt."
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(string: "")
        field.frame = NSRect(x: 0, y: 0, width: 280, height: 24)
        alert.accessoryView = field

        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            let path = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !path.isEmpty else { return }
            self?.createPath(path)
        }
    }

    private func createPath(_ relativePath: String) {
        let components = relativePath.split(separator: "/").map(String.init).filter { !$0.isEmpty }
        guard !components.isEmpty else { return }

        var url = currentURL
        var firstCreatedURL: URL?

        for (index, component) in components.enumerated() {
            url = url.appendingPathComponent(component)
            let isLast = index == components.count - 1

            guard !FileManager.default.fileExists(atPath: url.path) else { continue }

            do {
                if isLast && !url.pathExtension.isEmpty {
                    guard FileManager.default.createFile(atPath: url.path, contents: Data()) else {
                        throw FileOperationError.alreadyExists(component)
                    }
                } else {
                    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
                }
                if firstCreatedURL == nil {
                    firstCreatedURL = url
                }
            } catch {
                showFileOperationError(error)
                return
            }
        }

        if let firstCreatedURL {
            fileUndoManager.setActionName("New Item")
            fileUndoManager.registerUndo(withTarget: UndoTarget.shared) { _ in
                try? FileManager.default.trashItem(at: firstCreatedURL, resultingItemURL: nil)
            }
        }

        currentURL = url.deletingLastPathComponent()
        reload()
    }

    @objc func renameSelectedItem() {
        guard let entry = selectedEntry(), let window else { return }

        let alert = NSAlert()
        alert.messageText = "Rename \"\(entry.name)\""
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(string: entry.name)
        field.frame = NSRect(x: 0, y: 0, width: 260, height: 24)
        alert.accessoryView = field

        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            let newName = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !newName.isEmpty, newName != entry.name, let self else { return }
            do {
                try FileOperations.rename(entry.url, to: newName, undoManager: self.fileUndoManager)
                self.reload()
            } catch {
                self.showFileOperationError(error)
            }
        }
    }

    @objc func duplicateSelectedItem() {
        guard let entry = selectedEntry() else { return }
        do {
            try FileOperations.copy(entry.url, toDirectory: currentURL, undoManager: fileUndoManager)
            reload()
        } catch {
            showFileOperationError(error)
        }
    }

    @objc func moveSelectedItem() {
        guard let entry = selectedEntry(), let window else { return }
        let panel = destinationPanel()
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let destination = panel.url, let self else { return }
            do {
                try FileOperations.move(entry.url, toDirectory: destination, undoManager: self.fileUndoManager)
                self.reload()
            } catch {
                self.showFileOperationError(error)
            }
        }
    }

    @objc func copySelectedItem() {
        guard let entry = selectedEntry(), let window else { return }
        let panel = destinationPanel()
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let destination = panel.url, let self else { return }
            do {
                try FileOperations.copy(entry.url, toDirectory: destination, undoManager: self.fileUndoManager)
                self.reload()
            } catch {
                self.showFileOperationError(error)
            }
        }
    }

    private func destinationPanel() -> NSOpenPanel {
        let panel = NSOpenPanel()
        panel.title = "Choose destination"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        return panel
    }

    @objc func copySelectedItemToPasteboard() {
        guard let entry = selectedEntry() else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([entry.url as NSURL])
    }

    @objc func pasteFromPasteboard() {
        let pasteboard = NSPasteboard.general
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty else {
            return
        }
        for url in urls {
            do {
                try FileOperations.copy(url, toDirectory: currentURL, undoManager: fileUndoManager)
            } catch {
                showFileOperationError(error)
            }
        }
        reload()
    }

    func undo() {
        guard fileUndoManager.canUndo else { return }
        fileUndoManager.undo()
        reload()
    }

    func redo() {
        guard fileUndoManager.canRedo else { return }
        fileUndoManager.redo()
        reload()
    }

    // MARK: - SidebarSelectionHandling

    func sidebarDidSelect(url: URL) {
        currentURL = url
        reload()
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        displayedEntries.count
    }

    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        guard let descriptor = tableView.sortDescriptors.first, let key = descriptor.key else { return }
        switch key {
        case "name": sortKey = .name
        case "size": sortKey = .size
        case "modified": sortKey = .modificationDate
        default: return
        }
        sortAscending = descriptor.ascending
        applySortAndReload()
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let identifier = tableColumn?.identifier, row < displayedEntries.count else { return nil }
        let entry = displayedEntries[row]

        let cell: NSTableCellView
        if identifier == ColumnID.name {
            cell = DirectoryEntryCellFactory.makeOrReuseNameCell(in: tableView, identifier: identifier, owner: self)
        } else if let reused = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
            cell = reused
        } else {
            cell = NSTableCellView()
            cell.identifier = identifier

            let textField = NSTextField(labelWithString: "")
            textField.lineBreakMode = .byTruncatingTail
            textField.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(textField)
            cell.textField = textField

            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
        }

        switch identifier {
        case ColumnID.name:
            let iconSize = DirectoryEntryCellFactory.baseIconSize * CGFloat(AppSettings.shared.iconScale)
            DirectoryEntryCellFactory.configure(cell, for: entry, iconSize: iconSize)
        case ColumnID.size:
            cell.textField?.stringValue = entry.isDirectory ? "--" : sizeFormatter.string(fromByteCount: entry.fileSize)
        case ColumnID.modified:
            cell.textField?.stringValue = dateFormatter.string(from: entry.modificationDate)
        case ColumnID.kind:
            cell.textField?.stringValue = entry.isDirectory
                ? "Folder"
                : (entry.contentType?.localizedDescription ?? "Document")
        default:
            break
        }

        return cell
    }
}
