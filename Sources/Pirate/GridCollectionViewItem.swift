import AppKit

final class GridCollectionViewItem: NSCollectionViewItem {
    static let baseIconSize: CGFloat = 64
    static let baseItemSize = NSSize(width: 112, height: 126)

    private let iconView = NonHitTestingImageView()
    private let nameLabel = NSTextField(labelWithString: "")
    // Plain (non layer-backed) background for selection/drop-target feedback.
    // Grid drag-and-drop was unreliable right over the icon only when the item
    // was layer-backed (wantsLayer = true); this avoids Core Animation entirely.
    private let highlightBox = NSBox()

    override func loadView() {
        let container = NSView(frame: NSRect(origin: .zero, size: Self.baseItemSize))

        highlightBox.translatesAutoresizingMaskIntoConstraints = false
        highlightBox.boxType = .custom
        highlightBox.borderType = .noBorder
        highlightBox.fillColor = .clear
        highlightBox.cornerRadius = 6
        container.addSubview(highlightBox)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown
        container.addSubview(iconView)

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.alignment = .center
        nameLabel.lineBreakMode = .byTruncatingMiddle
        nameLabel.font = NSFont.systemFont(ofSize: 12)
        nameLabel.textColor = Theme.textPrimary
        container.addSubview(nameLabel)

        NSLayoutConstraint.activate([
            highlightBox.topAnchor.constraint(equalTo: container.topAnchor),
            highlightBox.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            highlightBox.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            highlightBox.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            iconView.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            iconView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: Self.baseIconSize),
            iconView.heightAnchor.constraint(equalToConstant: Self.baseIconSize),

            nameLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 6),
            nameLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            nameLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4)
        ])

        self.view = container
        self.imageView = iconView
        self.textField = nameLabel
    }

    override var isSelected: Bool {
        didSet {
            highlightBox.fillColor = isSelected
                ? NSColor.selectedContentBackgroundColor.withAlphaComponent(0.3)
                : .clear
        }
    }

    override var highlightState: NSCollectionViewItem.HighlightState {
        didSet {
            if highlightState == .asDropTarget {
                highlightBox.borderType = .lineBorder
                highlightBox.borderWidth = 2
                highlightBox.borderColor = Theme.accent
            } else {
                highlightBox.borderType = .noBorder
            }
        }
    }

    func configure(with entry: DirectoryEntry, iconSize: CGFloat) {
        iconView.image = IconCache.shared.icon(for: entry)
        nameLabel.stringValue = entry.name
        DirectoryEntryCellFactory.applyIconSize(iconSize, to: iconView)
    }
}
