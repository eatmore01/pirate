import Foundation

enum Benchmark {
    static func run(path: String) {
        let url = URL(fileURLWithPath: path, isDirectory: true)

        let listStart = DispatchTime.now()
        let entries: [DirectoryEntry]
        do {
            entries = try DirectoryLister.listDirectory(at: url)
        } catch {
            print("listDirectory failed: \(error)")
            exit(1)
        }
        let listEnd = DispatchTime.now()

        let sortStart = DispatchTime.now()
        let sortedEntries = DirectoryLister.sorted(entries)
        let sortEnd = DispatchTime.now()

        let listMs = Double(listEnd.uptimeNanoseconds - listStart.uptimeNanoseconds) / 1_000_000
        let sortMs = Double(sortEnd.uptimeNanoseconds - sortStart.uptimeNanoseconds) / 1_000_000

        let hiddenCount = entries.filter(\.isHidden).count
        let dirCount = entries.filter(\.isDirectory).count

        print("entries: \(entries.count)")
        print("directories: \(dirCount)")
        print("hidden: \(hiddenCount)")
        print("list time: \(String(format: "%.1f", listMs)) ms")
        print("sort time: \(String(format: "%.1f", sortMs)) ms")
        print("first 15 after sort:")
        for entry in sortedEntries.prefix(15) {
            let kind = entry.isDirectory ? "dir " : "file"
            let hidden = entry.isHidden ? " hidden" : ""
            print("  [\(kind)]\(hidden) \(entry.name)")
        }
    }
}
