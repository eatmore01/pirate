import Foundation

@MainActor
final class AppSettings {
    static let shared = AppSettings()
    static let showHiddenFilesDidChangeNotification = ConfigStore.didChangeNotification

    var showHiddenFiles: Bool {
        get { ConfigStore.shared.config.showHiddenFiles }
        set { ConfigStore.shared.update { $0.showHiddenFiles = newValue } }
    }

    var viewMode: ViewMode {
        get { ConfigStore.shared.config.viewMode }
        set { ConfigStore.shared.update { $0.viewMode = newValue } }
    }

    var iconScale: Double {
        get { ConfigStore.shared.config.iconScale }
        set { ConfigStore.shared.update { $0.iconScale = min(2.5, max(0.6, newValue)) } }
    }

    var askBeforeQuit: Bool {
        get { ConfigStore.shared.config.askBeforeQuit }
        set { ConfigStore.shared.update { $0.askBeforeQuit = newValue } }
    }
}
