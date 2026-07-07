import Foundation

/// User settings, persisted as ~/.config/tine/config.json (also hand-editable).
struct TineConfig: Codable, Equatable {
    var maxVisibleRows: Int = 12
    var glass: Bool = true          // Liquid Glass vs. a solid panel
    var accentTintName: String = "blue"
    var fontName: String = ""       // "" = system monospaced; else a named font
    var fontSize: Double = 12
    var firstTokenCompletion: Bool = true   // complete bare command names
    var showDetail: Bool = false            // Ctrl+K detail pane visible
    // User's own specs (loaded first, override the pack). Fig's equivalent of ~/.q/specs.
    var localSpecsDir: String = "\(NSHomeDirectory())/.tine/specs"

    /// The specs dir with a leading `~` expanded — safe to hand to the file layer.
    var localSpecsDirExpanded: String { (localSpecsDir as NSString).expandingTildeInPath }

    static let path = "\(NSHomeDirectory())/.config/tine/config.json"

    static func load() -> TineConfig {
        guard let data = FileManager.default.contents(atPath: path),
              let cfg = try? JSONDecoder().decode(TineConfig.self, from: data)
        else { return TineConfig() }
        return cfg
    }

    func save() {
        let dir = (Self.path as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(self) {
            try? data.write(to: URL(fileURLWithPath: Self.path))
        }
    }
}
