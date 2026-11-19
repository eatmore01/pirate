import Foundation
import UniformTypeIdentifiers

enum DirectoryLister {
    static let prefetchKeys: [URLResourceKey] = [
        .isDirectoryKey,
        .fileSizeKey,
        .contentModificationDateKey,
        .isHiddenKey,
        .isSymbolicLinkKey,
        .contentTypeKey
    ]

    static func listDirectory(at url: URL) throws -> [DirectoryEntry] {
        let urls = try FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: prefetchKeys,
            options: []
        )

        return urls.map { entryURL in
            let values = try? entryURL.resourceValues(forKeys: Set(prefetchKeys))
            return DirectoryEntry(
                url: entryURL,
                name: entryURL.lastPathComponent,
                isDirectory: values?.isDirectory ?? false,
                isSymbolicLink: values?.isSymbolicLink ?? false,
                isHidden: values?.isHidden ?? false,
                fileSize: Int64(values?.fileSize ?? 0),
                modificationDate: values?.contentModificationDate ?? Date(timeIntervalSince1970: 0),
                contentType: values?.contentType
            )
        }
    }

    enum SortKey {
        case name
        case size
        case modificationDate
    }

    static func sorted(_ entries: [DirectoryEntry], by key: SortKey = .name, ascending: Bool = true) -> [DirectoryEntry] {
        entries.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory
            }

            let ascendingResult: Bool
            switch key {
            case .name:
                ascendingResult = lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            case .size:
                ascendingResult = lhs.fileSize < rhs.fileSize
            case .modificationDate:
                ascendingResult = lhs.modificationDate < rhs.modificationDate
            }
            return ascending ? ascendingResult : !ascendingResult
        }
    }
}
