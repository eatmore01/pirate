import AppKit

final class GridCollectionViewItem: NSCollectionViewItem {
    static let baseIconSize: CGFloat = 64
    static let baseItemSize = NSSize(width: 112, height: 126)

    private let iconView = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")

    override func loadView() {
        let container = NSView(frame: NSRect(origin: .zero, size: Self.baseItemSize))

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
            view.layer?.backgroundColor = isSelected
                ? NSColor.selectedContentBackgroundColor.withAlphaComponent(0.3).cgColor
                : NSColor.clear.cgColor
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
        view.layer?.cornerRadius = 6
    }

    func configure(with entry: DirectoryEntry, iconSize: CGFloat) {
        iconView.image = IconCache.shared.icon(for: entry)
        nameLabel.stringValue = entry.name
        DirectoryEntryCellFactory.applyIconSize(iconSize, to: iconView)
    }
}
