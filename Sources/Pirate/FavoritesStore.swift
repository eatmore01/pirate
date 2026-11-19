import Foundation

final class FavoritesStore {
    private let defaultsKey = "com.kirillzuev.pirate.favorites.v1"
    private(set) var items: [FavoriteItem] = []

    init() {
        load()
    }

    private func load() {
        if let stored = UserDefaults.standard.array(forKey: defaultsKey) as? [[String: Any]], !stored.isEmpty {
            items = stored.compactMap { dict in
                guard let name = dict["name"] as? String, let data = dict["bookmark"] as? Data else { return nil }
                return FavoriteItem(name: name, bookmarkData: data)
            }
            return
        }

        items = Self.defaultFavorites()
        save()
    }

    private func save() {
        let encoded = items.map { ["name": $0.name, "bookmark": $0.bookmarkData] }
        UserDefaults.standard.set(encoded, forKey: defaultsKey)
    }

    func add(url: URL) {
        guard let bookmark = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) else {
            return
        }
        let name = url.lastPathComponent
        guard !items.contains(where: { $0.resolvedURL()?.path == url.path }) else { return }
        items.append(FavoriteItem(name: name, bookmarkData: bookmark))
        save()
    }

    func remove(at index: Int) {
        guard items.indices.contains(index) else { return }
        items.remove(at: index)
        save()
    }

    private static func defaultFavorites() -> [FavoriteItem] {
        let fm = FileManager.default
        var result: [FavoriteItem] = []

        let defaults: [(FileManager.SearchPathDirectory, String)] = [
            (.desktopDirectory, "Desktop"),
            (.downloadsDirectory, "Downloads")
        ]

        for (directory, name) in defaults {
            guard let url = try? fm.url(for: directory, in: .userDomainMask, appropriateFor: nil, create: false),
                  let bookmark = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) else {
                continue
            }
            result.append(FavoriteItem(name: name, bookmarkData: bookmark))
        }

        return result
    }
}
