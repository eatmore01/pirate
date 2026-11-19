import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var listWindowController: FileListWindowController!
    private var columnWindowController: ColumnBrowserWindowController!
    private let startURL: URL
    private let useColumnMode: Bool

    init(startURL: URL, useColumnMode: Bool) {
        self.startURL = startURL
        self.useColumnMode = useColumnMode
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .darkAqua)
        if useColumnMode {
            columnWindowController = ColumnBrowserWindowController(startingAt: startURL)
            columnWindowController.window?.makeKeyAndOrderFront(nil)
        } else {
            listWindowController = FileListWindowController(startingAt: startURL)
            listWindowController.window?.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

if CommandLine.arguments.count > 2, CommandLine.arguments[1] == "--bench" {
    Benchmark.run(path: CommandLine.arguments[2])
} else {
    let useColumnMode = CommandLine.arguments.contains("--columns")
    let pathArgument = CommandLine.arguments.dropFirst().first { $0 != "--columns" }

    let startURL: URL
    if let pathArgument {
        startURL = URL(fileURLWithPath: pathArgument, isDirectory: true)
    } else {
        startURL = FileManager.default.homeDirectoryForCurrentUser
    }

    let app = NSApplication.shared
    let delegate = AppDelegate(startURL: startURL, useColumnMode: useColumnMode)
    app.delegate = delegate
    app.setActivationPolicy(.regular)
    app.run()
}
