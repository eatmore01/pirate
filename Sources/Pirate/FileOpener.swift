import AppKit

@MainActor
enum FileOpener {
    static func open(_ entry: DirectoryEntry) {
        guard !entry.isDirectory else { return }

        if let appURL = resolvedApplicationURL(for: entry) {
            NSWorkspace.shared.open(
                [entry.url],
                withApplicationAt: appURL,
                configuration: NSWorkspace.OpenConfiguration()
            ) { @Sendable _, error in
                // LaunchServices invokes this on its own queue, not the main
                // actor - hop explicitly rather than inheriting isolation.
                guard let error else { return }
                Task { @MainActor in
                    NSAlert(error: error).runModal()
                }
            }
            return
        }

        NSWorkspace.shared.open(entry.url)
    }

    private static func resolvedApplicationURL(for entry: DirectoryEntry) -> URL? {
        let ext = entry.url.pathExtension
        guard !ext.isEmpty, let reference = FileTypeAssociationStore().appReference(forExtension: ext) else {
            return nil
        }
        return FileTypeAssociationStore.resolveAppURL(from: reference)
    }
}
