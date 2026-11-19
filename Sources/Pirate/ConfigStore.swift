import Foundation
import Yams

@MainActor
final class ConfigStore {
    static let shared = ConfigStore()
    static let didChangeNotification = Notification.Name("ConfigStore.didChange")

    private(set) var config: PirateConfig = .default

    private let configURL: URL
    private var watcherSource: DispatchSourceFileSystemObject?
    private var debounceWorkItem: DispatchWorkItem?

    private init() {
        let configDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/pirate", isDirectory: true)
        configURL = configDir.appendingPathComponent("config.yml")

        ensureFileExists(directory: configDir)
        load()
        startWatching()
    }

    private func ensureFileExists(directory: URL) {
        let fm = FileManager.default
        if !fm.fileExists(atPath: directory.path) {
            try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        if !fm.fileExists(atPath: configURL.path) {
            write(config: .default, notify: false)
        }
    }

    func load() {
        guard let text = try? String(contentsOf: configURL, encoding: .utf8) else { return }
        guard let decoded = try? YAMLDecoder().decode(PirateConfig.self, from: text) else { return }
        config = decoded
    }

    func update(_ transform: (inout PirateConfig) -> Void) {
        var updated = config
        transform(&updated)
        write(config: updated, notify: true)
    }

    private func write(config: PirateConfig, notify: Bool) {
        self.config = config
        if let text = try? YAMLEncoder().encode(config) {
            try? text.write(to: configURL, atomically: true, encoding: .utf8)
        }
        if notify {
            NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
        }
    }

    private func startWatching() {
        let fd = open(configURL.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            self?.debounceReload()
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
        watcherSource = source
    }

    private func debounceReload() {
        debounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.load()
            NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
            // Editors often replace the file (write-to-temp + rename) rather than
            // writing in place, which invalidates the fd-based watch on the old inode.
            self.watcherSource?.cancel()
            self.startWatching()
        }
        debounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: workItem)
    }
}
