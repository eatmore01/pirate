import Foundation
import UniformTypeIdentifiers

struct DirectoryEntry {
    let url: URL
    let name: String
    let isDirectory: Bool
    let isSymbolicLink: Bool
    let isHidden: Bool
    let fileSize: Int64
    let modificationDate: Date
    let contentType: UTType?
}
