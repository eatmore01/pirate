import AppKit

@MainActor
final class SettingsWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    static let shared = SettingsWindowController()

    private let store = FileTypeAssociationStore()
    private let tableView = NSTableView()
    private let hiddenCheckbox = NSButton(checkboxWithTitle: "Show hidden files", target: nil, action: nil)
    private let viewModeControl = NSSegmentedControl(labels: ["List", "Icons"], trackingMode: .selectOne, target: nil, action: nil)
    private let viewModeLabel = NSTextField(labelWithString: "View:")
    private let askBeforeQuitCheckbox = NSButton(checkboxWithTitle: "Ask before quitting", target: nil, action: nil)

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        super.init(window: window)
        window.center()
        setUp()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(configDidChange),
            name: ConfigStore.didChangeNotification,
            object: nil
        )
    }

    @objc private func configDidChange() {
        hiddenCheckbox.state = AppSettings.shared.showHiddenFiles ? .on : .off
        viewModeControl.selectedSegment = AppSettings.shared.viewMode == .grid ? 1 : 0
        askBeforeQuitCheckbox.state = AppSettings.shared.askBeforeQuit ? .on : .off
        tableView.reloadData()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("not supported")
    }

    private func setUp() {
        guard let window else { return }

        let container = NSView(frame: window.contentView?.bounds ?? .zero)
        container.autoresizingMask = [.width, .height]
        container.wantsLayer = true
        container.layer?.backgroundColor = Theme.ground.cgColor

        hiddenCheckbox.translatesAutoresizingMaskIntoConstraints = false
        hiddenCheckbox.state = AppSettings.shared.showHiddenFiles ? .on : .off
        hiddenCheckbox.target = self
        hiddenCheckbox.action = #selector(didToggleHidden)
        container.addSubview(hiddenCheckbox)

        viewModeLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(viewModeLabel)

        viewModeControl.translatesAutoresizingMaskIntoConstraints = false
        viewModeControl.selectedSegment = AppSettings.shared.viewMode == .grid ? 1 : 0
        viewModeControl.target = self
        viewModeControl.action = #selector(didChangeViewMode)
        container.addSubview(viewModeControl)

        askBeforeQuitCheckbox.translatesAutoresizingMaskIntoConstraints = false
        askBeforeQuitCheckbox.state = AppSettings.shared.askBeforeQuit ? .on : .off
        askBeforeQuitCheckbox.target = self
        askBeforeQuitCheckbox.action = #selector(didToggleAskBeforeQuit)
        container.addSubview(askBeforeQuitCheckbox)

        let label = NSTextField(labelWithString: "Open file types with:")
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        container.addSubview(scrollView)

        let typeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("type"))
        typeColumn.title = "Extension"
        typeColumn.width = 230
        let appColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("app"))
        appColumn.title = "Application"
        appColumn.width = 170
        tableView.addTableColumn(typeColumn)
        tableView.addTableColumn(appColumn)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = Theme.surface
        tableView.usesAlternatingRowBackgroundColors = false
        scrollView.drawsBackground = true
        scrollView.backgroundColor = Theme.surface
        scrollView.documentView = tableView

        let addButton = NSButton(title: "+", target: self, action: #selector(didTapAdd))
        addButton.translatesAutoresizingMaskIntoConstraints = false
        let removeButton = NSButton(title: "-", target: self, action: #selector(didTapRemove))
        removeButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(addButton)
        container.addSubview(removeButton)

        NSLayoutConstraint.activate([
            hiddenCheckbox.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            hiddenCheckbox.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),

            viewModeLabel.topAnchor.constraint(equalTo: hiddenCheckbox.bottomAnchor, constant: 16),
            viewModeLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),

            viewModeControl.centerYAnchor.constraint(equalTo: viewModeLabel.centerYAnchor),
            viewModeControl.leadingAnchor.constraint(equalTo: viewModeLabel.trailingAnchor, constant: 8),

            askBeforeQuitCheckbox.topAnchor.constraint(equalTo: viewModeLabel.bottomAnchor, constant: 16),
            askBeforeQuitCheckbox.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),

            label.topAnchor.constraint(equalTo: askBeforeQuitCheckbox.bottomAnchor, constant: 20),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),

            scrollView.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: addButton.topAnchor, constant: -8),

            addButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            addButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
            removeButton.leadingAnchor.constraint(equalTo: addButton.trailingAnchor, constant: 6),
            removeButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16)
        ])

        window.contentView = container
    }

    @objc private func didToggleHidden() {
        AppSettings.shared.showHiddenFiles = hiddenCheckbox.state == .on
    }

    @objc private func didChangeViewMode() {
        AppSettings.shared.viewMode = viewModeControl.selectedSegment == 1 ? .grid : .list
    }

    @objc private func didToggleAskBeforeQuit() {
        AppSettings.shared.askBeforeQuit = askBeforeQuitCheckbox.state == .on
    }

    @objc private func didTapAdd() {
        guard let window else { return }

        let alert = NSAlert()
        alert.messageText = "File extension"
        alert.informativeText = "e.g. mp3"
        alert.addButton(withTitle: "Next")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(string: "")
        field.frame = NSRect(x: 0, y: 0, width: 200, height: 24)
        alert.accessoryView = field

        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            let ext = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !ext.isEmpty else { return }
            self?.pickApplication(forExtension: ext, in: window)
        }
    }

    private func pickApplication(forExtension ext: String, in window: NSWindow) {
        let appPanel = NSOpenPanel()
        appPanel.title = "Choose an application"
        appPanel.directoryURL = URL(fileURLWithPath: "/Applications")
        appPanel.canChooseDirectories = false
        appPanel.canChooseFiles = true
        appPanel.allowsMultipleSelection = false

        appPanel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let appURL = appPanel.url else { return }
            let appName = appURL.deletingPathExtension().lastPathComponent
            self?.store.add(FileTypeAssociation(type: ext, app: appName))
            self?.tableView.reloadData()
        }
    }

    @objc private func didTapRemove() {
        guard tableView.selectedRow >= 0 else { return }
        store.remove(at: tableView.selectedRow)
        tableView.reloadData()
    }

    // MARK: - NSTableViewDataSource / Delegate

    func numberOfRows(in tableView: NSTableView) -> Int {
        store.associations.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let identifier = tableColumn?.identifier, row < store.associations.count else { return nil }
        let association = store.associations[row]

        let cellID = NSUserInterfaceItemIdentifier("settingsCell-\(identifier.rawValue)")
        let cell: NSTableCellView
        if let reused = tableView.makeView(withIdentifier: cellID, owner: self) as? NSTableCellView {
            cell = reused
        } else {
            cell = NSTableCellView()
            cell.identifier = cellID
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

        cell.textField?.stringValue = identifier.rawValue == "type" ? association.type : association.app
        return cell
    }
}
