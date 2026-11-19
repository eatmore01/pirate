import Foundation

struct FavoriteItem {
    var name: String
    var bookmarkData: Data

    func resolvedURL() -> URL? {
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return nil
        }
        return url
    }
}
