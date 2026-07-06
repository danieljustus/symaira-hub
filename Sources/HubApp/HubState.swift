import Foundation
import Observation
import SymairaToolKit

/// One sidebar entry: a registry tool plus its (optional) detection result.
struct ToolRow: Identifiable {
    let tool: SymairaTool
    let detected: DetectedTool?

    var id: String { tool.id }
    var isInstalled: Bool { detected != nil }
}

@Observable
@MainActor
final class HubState {
    private(set) var rows: [ToolRow] = []
    private(set) var isRefreshing = false
    private(set) var lastRefresh: Date?

    var selectedToolID: String?

    private let detector = ToolDetector()

    var selectedRow: ToolRow? {
        rows.first { $0.id == selectedToolID }
    }

    var installedCount: Int {
        rows.filter(\.isInstalled).count
    }

    /// Re-run runtime detection over the whole registry. Modules only
    /// "light up" for installed CLIs — the hub never requires them.
    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        var newRows: [ToolRow] = []
        for tool in SymairaToolRegistry.all {
            let detected = await detector.detect(tool)
            newRows.append(ToolRow(tool: tool, detected: detected))
        }
        // Installed tools first, alphabetical within each group.
        rows = newRows.sorted {
            if $0.isInstalled != $1.isInstalled { return $0.isInstalled }
            return $0.tool.displayName < $1.tool.displayName
        }
        lastRefresh = Date()

        if selectedToolID == nil {
            selectedToolID = rows.first?.id
        }
    }
}
