import Foundation

struct FileTypeAssociationConfig: Codable, Equatable {
    var type: String
    var app: String
}

enum ViewMode: String, Codable {
    case list
    case grid
}

struct PirateConfig: Codable, Equatable {
    var showHiddenFiles: Bool
    var viewMode: ViewMode
    var iconScale: Double
    var fileTypeAssociations: [FileTypeAssociationConfig]

    enum CodingKeys: String, CodingKey {
        case showHiddenFiles = "show_hidden_files"
        case viewMode = "view_mode"
        case iconScale = "icon_scale"
        case fileTypeAssociations = "file_type_associations"
    }

    init(showHiddenFiles: Bool, viewMode: ViewMode, iconScale: Double, fileTypeAssociations: [FileTypeAssociationConfig]) {
        self.showHiddenFiles = showHiddenFiles
        self.viewMode = viewMode
        self.iconScale = iconScale
        self.fileTypeAssociations = fileTypeAssociations
    }

    // Any field missing from an older config.yml falls back to its default
    // instead of failing the whole decode - keeps the schema forward-compatible.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        showHiddenFiles = try container.decodeIfPresent(Bool.self, forKey: .showHiddenFiles) ?? false
        viewMode = try container.decodeIfPresent(ViewMode.self, forKey: .viewMode) ?? .list
        iconScale = try container.decodeIfPresent(Double.self, forKey: .iconScale) ?? 1.0
        fileTypeAssociations = try container.decodeIfPresent([FileTypeAssociationConfig].self, forKey: .fileTypeAssociations) ?? []
    }

    static let `default` = PirateConfig(
        showHiddenFiles: false,
        viewMode: .list,
        iconScale: 1.0,
        fileTypeAssociations: [
            FileTypeAssociationConfig(type: "mp3", app: "VLC"),
            FileTypeAssociationConfig(type: "mp4", app: "VLC"),
            FileTypeAssociationConfig(type: "wav", app: "VLC"),
            FileTypeAssociationConfig(type: "avi", app: "VLC"),
            FileTypeAssociationConfig(type: "mkv", app: "VLC"),
            FileTypeAssociationConfig(type: "mov", app: "VLC"),
            FileTypeAssociationConfig(type: "flac", app: "VLC")
        ]
    )
}
