import AppKit

@MainActor
enum DirectoryEntryCellFactory {
    static let baseIconSize: CGFloat = 20

    static func makeOrReuseNameCell(in tableView: NSTableView, identifier: NSUserInterfaceItemIdentifier, owner: Any?) -> NSTableCellView {
        if let reused = tableView.makeView(withIdentifier: identifier, owner: owner) as? NSTableCellView {
            return reused
        }

        let cell = NSTableCellView()
        cell.identifier = identifier

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
            imageView.widthAnchor.constraint(equalToConstant: baseIconSize),
            imageView.heightAnchor.constraint(equalToConstant: baseIconSize),
            textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 6),
            textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])

        return cell
    }

    static func configure(_ cell: NSTableCellView, for entry: DirectoryEntry, iconSize: CGFloat = baseIconSize) {
        cell.textField?.stringValue = entry.name
        cell.imageView?.image = IconCache.shared.icon(for: entry)
        applyIconSize(iconSize, to: cell.imageView)
    }

    static func applyIconSize(_ size: CGFloat, to imageView: NSImageView?) {
        guard let imageView else { return }
        for constraint in imageView.constraints where constraint.firstAttribute == .width || constraint.firstAttribute == .height {
            constraint.constant = size
        }
    }
}
