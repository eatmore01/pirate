import AppKit
import UniformTypeIdentifiers

@MainActor
final class IconCache {
    static let shared = IconCache()

    private let cache = NSCache<NSString, NSImage>()
    private let folderKey: NSString = "public.folder"

    func icon(for entry: DirectoryEntry) -> NSImage {
        if entry.isDirectory {
            if let cached = cache.object(forKey: folderKey) {
                return cached
            }
            let icon = NSWorkspace.shared.icon(for: .folder)
            cache.setObject(icon, forKey: folderKey)
            return icon
        }

        let type = entry.contentType ?? .item
        let key = type.identifier as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        let icon = NSWorkspace.shared.icon(for: type)
        cache.setObject(icon, forKey: key)
        return icon
    }
}
