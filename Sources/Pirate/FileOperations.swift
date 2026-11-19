import Foundation

enum FileOperationError: LocalizedError {
    case alreadyExists(String)

    var errorDescription: String? {
        switch self {
        case .alreadyExists(let name):
            return "\"\(name)\" already exists at the destination."
        }
    }
}

final class UndoTarget: NSObject, @unchecked Sendable {
    static let shared = UndoTarget()
}

struct FileOperations {

    static func trash(_ url: URL, undoManager: UndoManager) throws {
        var resultingURL: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &resultingURL)
        guard let trashedURL = resultingURL as URL? else { return }
        registerTrashUndo(originalURL: url, trashedURL: trashedURL, undoManager: undoManager)
    }

    private static func registerTrashUndo(originalURL: URL, trashedURL: URL, undoManager: UndoManager) {
        undoManager.setActionName("Move to Trash")
        undoManager.registerUndo(withTarget: UndoTarget.shared) { target in
            try? FileManager.default.moveItem(at: trashedURL, to: originalURL)
            undoManager.setActionName("Move to Trash")
            undoManager.registerUndo(withTarget: target) { _ in
                var newResultingURL: NSURL?
                try? FileManager.default.trashItem(at: originalURL, resultingItemURL: &newResultingURL)
                if let newTrashed = newResultingURL as URL? {
                    registerTrashUndo(originalURL: originalURL, trashedURL: newTrashed, undoManager: undoManager)
                }
            }
        }
    }

    static func rename(_ url: URL, to newName: String, undoManager: UndoManager) throws {
        let destination = url.deletingLastPathComponent().appendingPathComponent(newName)
        guard !FileManager.default.fileExists(atPath: destination.path) else {
            throw FileOperationError.alreadyExists(newName)
        }
        try FileManager.default.moveItem(at: url, to: destination)
        registerMoveUndo(from: url, to: destination, actionName: "Rename", undoManager: undoManager)
    }

    static func move(_ url: URL, toDirectory directory: URL, undoManager: UndoManager) throws {
        let destination = uniqueDestination(for: url.lastPathComponent, in: directory)
        try FileManager.default.moveItem(at: url, to: destination)
        registerMoveUndo(from: url, to: destination, actionName: "Move", undoManager: undoManager)
    }

    private static func registerMoveUndo(from source: URL, to destination: URL, actionName: String, undoManager: UndoManager) {
        undoManager.setActionName(actionName)
        undoManager.registerUndo(withTarget: UndoTarget.shared) { target in
            try? FileManager.default.moveItem(at: destination, to: source)
            undoManager.setActionName(actionName)
            registerMoveUndo(from: destination, to: source, actionName: actionName, undoManager: undoManager)
        }
    }

    // Undo trashes the created copy. Redoing after an undo creates a fresh copy
    // rather than restoring the exact original name - acceptable for v1.
    static func copy(_ url: URL, toDirectory directory: URL, undoManager: UndoManager) throws {
        let destination = uniqueDestination(for: url.lastPathComponent, in: directory)
        try FileManager.default.copyItem(at: url, to: destination)

        undoManager.setActionName("Copy")
        undoManager.registerUndo(withTarget: UndoTarget.shared) { _ in
            try? FileManager.default.trashItem(at: destination, resultingItemURL: nil)
        }
    }

    private static func uniqueDestination(for name: String, in directory: URL) -> URL {
        let fm = FileManager.default
        var candidate = directory.appendingPathComponent(name)
        guard fm.fileExists(atPath: candidate.path) else { return candidate }

        let ext = (name as NSString).pathExtension
        let base = ext.isEmpty ? name : String(name.dropLast(ext.count + 1))
        var counter = 2
        repeat {
            let newName = ext.isEmpty ? "\(base) \(counter)" : "\(base) \(counter).\(ext)"
            candidate = directory.appendingPathComponent(newName)
            counter += 1
        } while fm.fileExists(atPath: candidate.path)
        return candidate
    }
}
