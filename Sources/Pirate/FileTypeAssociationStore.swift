import AppKit

struct FileTypeAssociation {
    var type: String
    var app: String
}

@MainActor
final class FileTypeAssociationStore {
    var associations: [FileTypeAssociation] {
        ConfigStore.shared.config.fileTypeAssociations.map {
            FileTypeAssociation(type: $0.type, app: $0.app)
        }
    }

    func add(_ association: FileTypeAssociation) {
        ConfigStore.shared.update { config in
            config.fileTypeAssociations.removeAll { $0.type.caseInsensitiveCompare(association.type) == .orderedSame }
            config.fileTypeAssociations.append(
                FileTypeAssociationConfig(type: association.type, app: association.app)
            )
        }
    }

    func remove(at index: Int) {
        ConfigStore.shared.update { config in
            guard config.fileTypeAssociations.indices.contains(index) else { return }
            config.fileTypeAssociations.remove(at: index)
        }
    }

    // Matched by plain file extension, e.g. "mp3" - not a UTType identifier.
    func appReference(forExtension ext: String) -> String? {
        ConfigStore.shared.config.fileTypeAssociations.first {
            $0.type.caseInsensitiveCompare(ext) == .orderedSame
        }?.app
    }

    // Accepts, in order: a filesystem path (to the .app or to a binary inside
    // one - walked up to its enclosing .app), a bundle identifier
    // ("org.videolan.vlc"), or a plain app name as it reads in Finder ("VLC").
    static func resolveAppURL(from reference: String) -> URL? {
        if reference.hasPrefix("/") {
            return resolveAppURL(fromPath: reference)
        }
        if let byBundleID = NSWorkspace.shared.urlForApplication(withBundleIdentifier: reference) {
            return byBundleID
        }
        return resolveAppURL(byName: reference)
    }

    private static func resolveAppURL(fromPath path: String) -> URL? {
        var url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }

        while url.pathExtension != "app" {
            let parent = url.deletingLastPathComponent()
            guard parent.path != url.path else { return nil }
            url = parent
        }
        return url
    }

    private static func resolveAppURL(byName name: String) -> URL? {
        let fm = FileManager.default
        let fileName = name.hasSuffix(".app") ? name : "\(name).app"

        let searchDirectories = [
            "/Applications",
            "/System/Applications",
            "\(NSHomeDirectory())/Applications"
        ]

        for directory in searchDirectories {
            guard let entries = try? fm.contentsOfDirectory(atPath: directory) else { continue }
            if let match = entries.first(where: { $0.caseInsensitiveCompare(fileName) == .orderedSame }) {
                return URL(fileURLWithPath: directory).appendingPathComponent(match)
            }
        }
        return nil
    }
}
